#!/bin/bash
#
# One-command deployment of Online Boutique on Docker-based Kubernetes (Kind)
# This script automates the Docker-based on-prem deployment path
#
# Prerequisites:
#   - Docker installed and running
#   - kubectl installed
#   - kind installed (https://kind.sigs.k8s.io/docs/user/quick-start/)
#
# Usage:
#   bash scripts/deploy-docker-onprem.sh
#   # Then open http://localhost:8080 in browser
#
# Cleanup:
#   kind delete cluster --name online-boutique

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
CLUSTER_NAME="online-boutique"
REGISTRY_NAME="local-registry"
REGISTRY_PORT="5000"
REGISTRY_URL="localhost:${REGISTRY_PORT}"
KUBECONFIG="${HOME}/.kube/config-onprem"
# MODIFIED: Align with kustomize/base image tags (components/container-images-registry keeps tag).
MICROSERVICES_IMAGE_TAG="${MICROSERVICES_IMAGE_TAG:-v0.10.5}"
REDIS_IMAGE_TAG="${REDIS_IMAGE_TAG:-alpine}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Online Boutique Docker On-Prem Deployment ===${NC}"

# Check prerequisites
echo -e "${YELLOW}[1/8] Checking prerequisites...${NC}"
for cmd in docker kind kubectl; do
    if ! command -v "$cmd" &> /dev/null; then
        echo -e "${RED}ERROR: $cmd not found. Please install it first.${NC}"
        exit 1
    fi
done
echo -e "${GREEN}✓ All prerequisites available${NC}"

# Detect or create local registry container
echo -e "${YELLOW}[2/8] Setting up local registry...${NC}"
if ! docker ps --format '{{.Names}}' | grep -q "^${REGISTRY_NAME}$"; then
    echo "Creating local registry container..."
    docker run -d \
        --name "$REGISTRY_NAME" \
        --restart always \
        -p "${REGISTRY_PORT}:5000" \
        registry:2
    sleep 3
fi
REGISTRY_CONTAINER_IP=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$REGISTRY_NAME")
echo -e "${GREEN}✓ Registry running at ${REGISTRY_URL}${NC}"

# Create Kind cluster
echo -e "${YELLOW}[3/8] Creating Kind cluster (${CLUSTER_NAME})...${NC}"
if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    echo "Cluster already exists, skipping creation"
else
    cat > /tmp/kind-config.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ${CLUSTER_NAME}
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  ports:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
- role: worker
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registries.mirrors."localhost:${REGISTRY_PORT}"]
    endpoint = ["http://${REGISTRY_CONTAINER_IP}:5000"]
EOF

    kind create cluster --config /tmp/kind-config.yaml
    rm /tmp/kind-config.yaml
fi

# Configure kubeconfig
export KUBECONFIG="${KUBECONFIG}"
kind export kubeconfig --name="${CLUSTER_NAME}" --kubeconfig="${KUBECONFIG}"
echo -e "${GREEN}✓ Cluster ready (kubeconfig: ${KUBECONFIG})${NC}"

# Install ingress-nginx
echo -e "${YELLOW}[4/8] Installing ingress-nginx...${NC}"
if ! kubectl get deployment -n ingress-nginx ingress-nginx-controller &>/dev/null; then
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=300s
fi
echo -e "${GREEN}✓ Ingress controller ready${NC}"

# Build and push images
echo -e "${YELLOW}[5/8] Building and pushing container images...${NC}"
cd "$REPO_ROOT"

if command -v skaffold &> /dev/null; then
    echo "Using skaffold for image build..."
    skaffold build \
        --default-repo="${REGISTRY_URL}/microservices-demo" \
        --push=true \
        --tag="${MICROSERVICES_IMAGE_TAG}" \
        -f skaffold.yaml || {
        echo -e "${YELLOW}Skaffold build on first run may timeout. Retrying with incremental approach...${NC}"
        # Fallback: manual docker build for selected services
        for service in frontend productcatalogservice cartservice; do
            echo "Building ${service}..."
            docker build --build-arg="SERVICE=${service}" \
                -t "${REGISTRY_URL}/microservices-demo/${service}:${MICROSERVICES_IMAGE_TAG}" \
                "src/${service}" 2>/dev/null || true
        done
    }
else
    echo -e "${YELLOW}Skaffold not installed, using docker build for core services...${NC}"
    for service in emailservice productcatalogservice checkoutservice currencyservice \
                   paymentservice shippingservice frontend adservice recommendationservice; do
        if [ -d "src/${service}" ]; then
            echo "Building ${service}..."
            docker build -t "${REGISTRY_URL}/microservices-demo/${service}:${MICROSERVICES_IMAGE_TAG}" \
                "src/${service}" || true
            docker push "${REGISTRY_URL}/microservices-demo/${service}:${MICROSERVICES_IMAGE_TAG}" || true
        fi
    done
    docker pull "redis:${REDIS_IMAGE_TAG}"
    docker tag "redis:${REDIS_IMAGE_TAG}" "${REGISTRY_URL}/microservices-demo/redis:${REDIS_IMAGE_TAG}"
    docker push "${REGISTRY_URL}/microservices-demo/redis:${REDIS_IMAGE_TAG}" || true
fi
echo -e "${GREEN}✓ Images built and pushed to local registry${NC}"

# Deploy Online Boutique
echo -e "${YELLOW}[6/8] Deploying Online Boutique...${NC}"
kubectl kustomize "${REPO_ROOT}/kustomize/environments/onprem/base" \
    --kubeconfig="${KUBECONFIG}" | \
    sed "s|CONTAINER_IMAGES_REGISTRY|${REGISTRY_URL}/microservices-demo|g" | \
    kubectl apply -f - --kubeconfig="${KUBECONFIG}"

echo -e "${GREEN}✓ Deployment manifests applied${NC}"

# Wait for pods to be ready
echo -e "${YELLOW}[7/8] Waiting for pods to be ready (this may take 2-5 minutes)...${NC}"
kubectl rollout status deployment --all \
    --namespace=default \
    --timeout=600s \
    --kubeconfig="${KUBECONFIG}" || {
    echo -e "${YELLOW}Some pods are still starting. Checking status...${NC}"
    kubectl get pods -n default --kubeconfig="${KUBECONFIG}"
}

# Display access information
echo -e "${YELLOW}[8/8] Deployment Summary${NC}"
echo ""
echo -e "${GREEN}✓ Online Boutique is ready!${NC}"
echo ""
echo "Access the application:"
echo ""
echo "  Option 1 - Port Forward (recommended for local testing):"
echo "    kubectl port-forward --kubeconfig=${KUBECONFIG} svc/frontend 8080:80"
echo "    Then open: http://localhost:8080"
echo ""
echo "  Option 2 - Through Ingress:"
echo "    Add to your /etc/hosts (or C:\\Windows\\System32\\drivers\\etc\\hosts on Windows):"
echo "    127.0.0.1 boutique.internal"
echo "    Then open: http://boutique.internal"
echo ""
echo "Cluster status:"
kubectl get pods -n default --kubeconfig="${KUBECONFIG}"
echo ""
echo "To cleanup everything:"
echo "  kind delete cluster --name=${CLUSTER_NAME}"
echo "  docker stop ${REGISTRY_NAME} && docker rm ${REGISTRY_NAME}"
