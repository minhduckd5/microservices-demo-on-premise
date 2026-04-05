# On-Prem Deployment Guide for Online Boutique

This guide covers two on-prem deployment paths for Online Boutique:
1. **Vagrant + VMware + K3s + Ansible** — Multi-node production-like setup with full IaC
2. **Docker-based (Kind)** — Fast local-only testing, no VMs needed

---

## Decision Tree: Which Path for You?

| Criterion | Vagrant + K3s | Docker-based (Kind) |
|-----------|---------------|-------------------|
| **Use case** | Production-like on-prem testing, multi-node | Local dev/testing, quick demos |
| **VMs required** | Yes (3-4) | No |
| **Setup time** | 15-30 minutes | 5-10 minutes |
| **Resource usage** | 12+ GB RAM, 50+ GB disk | 4-8 GB RAM, 20 GB disk |
| **IaC managed** | Terraform + Ansible | Shell script |
| **Networking** | Bridged static IPs (default `192.168.1.210`–`.220`) | Localhost only |
| **Scalability** | Can add more worker nodes | Fixed to 1 control + 1 worker |
| **Persistence** | Survives host reboot | Lost on cluster deletion |

---

## Path 1: Vagrant + VMware + K3s + Ansible

### Prerequisites

- [Vagrant](https://www.vagrantup.com/downloads) 2.4+
- [VMware Fusion/Workstation Pro](https://www.vmware.com/) (or VirtualBox as fallback)
- [Vagrant VMware plugin](https://www.vagrantup.com/docs/vmware): `vagrant plugin install vagrant-vmware-desktop`
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/index.html) 2.9+
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- 12+ GB RAM, 50+ GB disk available
- **Windows only**: Git Bash or WSL for shell script execution

### Step 1: Spin Up Vagrant VMs

```bash
cd vagrant/
vagrant validate
vagrant up
```

This provisions:
- `k3s-control` (`192.168.1.210`): 2 CPUs, 4 GB RAM — Control-plane
- `k3s-worker1` (`192.168.1.211`): 2 CPUs, 2 GB RAM — Worker
- `k3s-worker2` (`192.168.1.212`): 2 CPUs, 2 GB RAM — Worker
- `registry-vm` (`192.168.1.220`): 2 CPUs, 2 GB RAM — Docker Registry 2 (image storage for the cluster)

Override with `VMWARE_IP_PREFIX` / `VMWARE_GATEWAY` before `vagrant up`, then align **`ansible/inventory/hosts.yml`** to the same subnet.

**Estimated time**: 15 minutes (first run), 2-3 minutes (subsequent).

Verify VMs are running:

```bash
vagrant status
# Expected:
# k3s-control                 running (vmware_desktop)
# k3s-worker1                 running (vmware_desktop)
# k3s-worker2                 running (vmware_desktop)
# registry-vm                 running (vmware_desktop)
```

### Step 2: Bootstrap K3s Cluster with Ansible

From the repository root:

```bash
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/k3s-bootstrap.yml -v
```

This:
1. Installs K3s server (control-plane)
2. Joins workers to the cluster
3. Verifies all nodes are `Ready`
4. Outputs kubeconfig to `./k3s-kubeconfig`

**Expected output**:
```
PLAY RECAP **************************
k3s-control : ok=XX changed=XX unreachable=0 failed=0
k3s-worker1 : ok=XX changed=XX unreachable=0 failed=0
k3s-worker2 : ok=XX changed=XX unreachable=0 failed=0
```

### Step 3: Set Up Local Docker Registry

```bash
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/registry-vm.yml -v
```

This:
1. Starts Docker Registry 2.0 on `registry-vm` (port 5000)
2. Adds `registry.local` to `/etc/hosts` on all cluster nodes
3. Writes **`/etc/rancher/k3s/registries.yaml`** on **control plane and workers** so HTTP pulls to `registry.local:5000` work (required for pods scheduled on workers)
4. Configures Docker on `k3s-control` for **insecure** `registry.local:5000` (for `docker push`)
5. Verifies the registry responds

**Expected output** (IP follows `registry_ip` in inventory):
```
✓ Local Docker Registry is running on 192.168.1.220:5000
✓ All K3s nodes configured to use registry.local:5000
```

### Step 4: Build, Push, and Deploy Images

```bash
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/deploy-app.yml -v
```

This:
1. Syncs the repo to the control plane and **docker build** / **docker push** each service with tag **`microservices_image_tag`** (default **`v0.10.5`**, matching `kustomize/base`)
2. Pulls **`redis:alpine`**, retags, and pushes **`.../microservices-demo/redis:alpine`**
3. Renders and applies `kubectl kustomize kustomize/environments/onprem/k3s` with `CONTAINER_IMAGES_REGISTRY` substitution
4. Waits for each Deployment with `kubectl rollout status` (per deployment; no `--all` flag)

**Expected output**:
```
✓ Online Boutique deployed successfully!
NAME                                 READY   STATUS    RESTARTS   AGE
adservice-xxx                        1/1     Running   0          2m
cartservice-xxx                      1/1     Running   0          2m
...
```

### Automated Full Deployment (One Command)

Instead of running playbooks individually, use the orchestration script:

```bash
cd scripts/
bash run-ansible.sh
```

This runs all steps in sequence. Add `--check` for dry-run or `--step` for interactive mode.

### Step 5: Access the Deployment

#### Option A: Port-forward (recommended for testing)

The **frontend** Service uses **port 80** → pod **8080**. Forward local **8080** to service **80**:

```bash
export KUBECONFIG=./k3s-kubeconfig
kubectl port-forward -n default svc/frontend 8080:80
```

Open **http://localhost:8080** on the **same machine** running `kubectl`.

- To reach the UI from **another PC** on the LAN, either run  
  `kubectl port-forward -n default --address 0.0.0.0 svc/frontend 8080:80`  
  on a node with kubeconfig and browse `http://<control-plane-ip>:8080`, or use **SSH local forwarding** (`ssh -L 8080:127.0.0.1:8080 vagrant@<control-ip>`).

#### Option B: Ingress + hostname `boutique.internal`

The on-prem **k3s** overlay sets **IngressClassName `traefik`**. You need a matching ingress controller for this path to work; many users rely on **port-forward** instead.

If ingress is working, add to `/etc/hosts` (Linux/Mac) or `C:\Windows\System32\drivers\etc\hosts` (Windows), using your **control-plane** IP:

```
192.168.1.210  boutique.internal
```

Then open: **http://boutique.internal**

### Verify Full Deployment

```bash
# Check all pods are running
kubectl get pods -A

# Check ingress
kubectl get ingress

# Check services
kubectl get svc

# Stream logs from a specific service
kubectl logs -f deploy/frontend

# Port-forward specific service
kubectl port-forward svc/frontend 8080:80
```

### Troubleshooting

| Issue | Solution |
|-------|----------|
| VMs won't start (VMware error) | Fallback to VirtualBox: `VAGRANT_DEFAULT_PROVIDER=virtualbox vagrant up` |
| K3s bootstrap fails | SSH into control-plane: `vagrant ssh k3s-control` and check `/var/log/k3s.log` |
| Pods in `ImagePullBackOff` | (1) Images/tags in registry — re-run **deploy-app**; check `curl http://<registry-ip>:5000/v2/<name>/tags/list`. (2) **Workers** must have `/etc/rancher/k3s/registries.yaml` — re-run **registry-vm.yml**. (3) `registry.local` in `/etc/hosts` on every node. |
| Ingress not accessible | Ensure hosts entry: `boutique.internal` → **control-plane** IP (e.g. `192.168.1.210`); ingress class must match (e.g. Traefik) |
| `unknown flag: --all` | Use per-deployment rollout or `kubectl delete pods -n default --all` — see [QUICKSTART-VAGRANT-ANSIBLE.md](./QUICKSTART-VAGRANT-ANSIBLE.md) |
| Ansible SSH connection refused | Wait 30 seconds for VMs to fully boot, then retry playbook |

### Cleanup

To destroy the entire Vagrant setup:

```bash
cd vagrant/
vagrant destroy -f
```

---

## Path 2: Docker-Based On-Prem (Kind)

### Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) or Docker Engine
- [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- 4-8 GB RAM, 20 GB disk
- **Windows**: Docker Desktop or WSL2 Docker

### One-Command Deployment

```bash
cd scripts/
bash deploy-docker-onprem.sh
```

This script:
1. Spins up local registry (Docker container on localhost:5000)
2. Creates Kind cluster (`online-boutique`)
3. Installs ingress-nginx
4. Builds and pushes images to local registry
5. Deploys Online Boutique via kustomize
6. Waits for all pods to be ready

**Estimated time**: 10-15 minutes (first run), 5 minutes (subsequent).

**Expected output**:
```
=== Online Boutique Docker On-Prem Deployment ===
[1/8] Checking prerequisites...
✓ All prerequisites available
...
[8/8] Deployment Summary
✓ Online Boutique is ready!

Access the application:
  Option 1 - Port Forward:
    kubectl port-forward --kubeconfig=~/.kube/config-onprem svc/frontend 8080:80
    Then open: http://localhost:8080
```

### Access the Deployment

#### Option A: Port-Forward

```bash
export KUBECONFIG=~/.kube/config-onprem
kubectl port-forward svc/frontend 8080:80
```

Then open: **http://localhost:8080**

#### Option B: Ingress + DNS Masquerading

On Linux/Mac with `dnsmasq` or on Windows with manual hosts entry:

1. Add to `/etc/hosts`:
   ```
   127.0.0.1 boutique.internal
   ```

2. Open: **http://boutique.internal**

### Cleanup

```bash
kind delete cluster --name=online-boutique
docker stop local-registry && docker rm local-registry
```

---

## Verification Checklist

### For Both Paths

- [ ] All pods are in `Running` state: `kubectl get pods`
- [ ] Ingress is configured: `kubectl get ingress`
- [ ] Frontend is accessible via port-forward or ingress
- [ ] All microservices are responding (check logs for errors)
- [ ] Load generator is creating realistic traffic

### Debugging Commands

```bash
# View pod logs
kubectl logs -f pod/<pod-name>

# Describe pod for events
kubectl describe pod/<pod-name>

# Check resource usage
kubectl top pods

# Inspect deployment
kubectl describe deployment/<deployment-name>

# Check events
kubectl get events

# Port-forward to any service
kubectl port-forward svc/<service> <local-port>:<remote-port>
```

---

## Next Steps

1. **Customization**: Edit [kustomize/kustomization.yaml](../../kustomize/kustomization.yaml) to enable components (e.g., `cymbal-branding`, `network-policies`)
2. **Observability**: Deploy OpenTelemetry stack (see [kustomize/components/observability-onprem](../../kustomize/components/observability-onprem/))
3. **Testing**: Run load testing via `loadgenerator` or custom scripts
4. **CI/CD Integration**: Version-control Vagrant/Ansible configs in your repo; integrate into CI pipeline

---

## FAQ

**Q: Can I add more worker nodes to the Vagrant cluster?**

A: Yes. Edit `vagrant/Vagrantfile` and add more entries to the `machines` array, then run `vagrant up`.

**Q: How do I push custom images to the registry?**

A: For Vagrant: push to `registry.local:5000/your-image:tag` from any cluster node.  
For Kind: push to `localhost:5000/your-image:tag` from your local machine.

**Q: Can I switch from Vagrant to Docker-based mid-deployment?**

A: Not easily—they use separate networks and registries. Start fresh with the other path.

**Q: What if my machine doesn't support VMware?**

A: Vagrant automatically falls back to VirtualBox. Set `VAGRANT_DEFAULT_PROVIDER=virtualbox vagrant up`.

**Q: How do I persist data across redeployments?**

A: For Vagrant: data persists on VMs until `vagrant destroy`.  
For Kind: use persistent volumes (PVs) bound to host mounts, or re-run the deployment script.

---

## Support & Troubleshooting

- **K3s docs**: https://docs.k3s.io/
- **Ansible docs**: https://docs.ansible.com/
- **Kind docs**: https://kind.sigs.k8s.io/
- **Online Boutique repo**: https://github.com/GoogleCloudPlatform/microservices-demo

For specific issues, check:
1. Pod logs: `kubectl logs <pod>`
2. Ansible playbook output for errors
3. VM system logs: `vagrant ssh <vm> -- sudo journalctl -u k3s`
