#!/bin/bash
# Ansible playbook runner for Online Boutique on-prem deployment
#
# Orchestrates the full Vagrant + K3s + app deployment pipeline
#
# Usage:
#   bash scripts/run-ansible.sh              # Run all playbooks in sequence
#   bash scripts/run-ansible.sh --check      # Dry-run mode
#   bash scripts/run-ansible.sh --step       # Interactive step-by-step

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
ANSIBLE_DIR="${REPO_ROOT}/ansible"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

CHECK_MODE=""
STEP_MODE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --check) CHECK_MODE="--check" ;;
        --step) STEP_MODE="--step" ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

echo -e "${YELLOW}=== Online Boutique On-Prem Deployment (Vagrant + Ansible) ===${NC}"

# Check prerequisites
echo -e "${YELLOW}[1] Checking prerequisites...${NC}"
for cmd in vagrant ansible ansible-playbook; do
    if ! command -v "$cmd" &> /dev/null; then
        echo -e "${RED}ERROR: $cmd not found. Please install it first.${NC}"
        exit 1
    fi
done
echo -e "${GREEN}✓ All prerequisites available${NC}"

cd "${REPO_ROOT}/vagrant"

# Step 1: Vagrant up
echo -e "${YELLOW}[2] Starting Vagrant VMs...${NC}"
vagrant validate
vagrant up --provider=vmware_desktop

# Step 2: K3s bootstrap
echo -e "${YELLOW}[3] Bootstrapping K3s cluster...${NC}"
cd "${REPO_ROOT}"
ansible-playbook -i "${ANSIBLE_DIR}/inventory/hosts.yml" \
    "${ANSIBLE_DIR}/playbooks/k3s-bootstrap.yml" \
    ${CHECK_MODE} ${STEP_MODE} -v

# Step 3: Registry setup
echo -e "${YELLOW}[4] Setting up Docker registry...${NC}"
ansible-playbook -i "${ANSIBLE_DIR}/inventory/hosts.yml" \
    "${ANSIBLE_DIR}/playbooks/registry-vm.yml" \
    ${CHECK_MODE} ${STEP_MODE} -v

# Step 4: App deployment
echo -e "${YELLOW}[5] Deploying Online Boutique...${NC}"
ansible-playbook -i "${ANSIBLE_DIR}/inventory/hosts.yml" \
    "${ANSIBLE_DIR}/playbooks/deploy-app.yml" \
    ${CHECK_MODE} ${STEP_MODE} -v

echo -e "${GREEN}=== Deployment Complete! ===${NC}"
echo ""
echo "Next steps:"
echo "  1. Retrieve kubeconfig: scp -i vagrant/.vagrant/machines/k3s-control/provider/private_key vagrant@192.168.1.10:~/.kube/config ~/.kube/config-onprem"
echo "  2. Set KUBECONFIG: export KUBECONFIG=~/.kube/config-onprem"
echo "  3. Access app via port-forward: kubectl port-forward svc/frontend 8080:80"
echo "  4. Or add to /etc/hosts: 192.168.1.10 boutique.internal"
