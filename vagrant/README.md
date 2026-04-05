# Vagrant Setup for Online Boutique On-Prem

This directory contains Vagrant configuration for spinning up a multi-node K3s cluster (1 control-plane + 2 workers) on VMware or VirtualBox.

Bridged networking applies static addresses in `192.168.1.0/24` by default (`VMWARE_IP_PREFIX`, `VMWARE_GATEWAY` in `Vagrantfile`). **Keep the same prefix in `ansible/inventory/hosts.yml`.**

## Prerequisites

- [Vagrant](https://www.vagrantup.com/downloads) 2.4+
- [VMware Desktop (Fusion/Workstation Pro)](https://www.vmware.com/) with [Vagrant VMware plugin](https://www.vagrantup.com/docs/vmware) installed
  - **OR** VirtualBox 7.0+ (automatically selected if VMware not available)
- 12+ GB RAM available on host (4GB control-plane + 2x 2GB workers + 2GB registry)
- 50+ GB disk space

## Quick Start

### 1. Validate and Boot VMs

```bash
cd vagrant/
VMWARE_BRIDGE=VMnet8 vagrant validate    # Optional: choose bridge network name
vagrant validate    # Syntax check
vagrant up         # Boots all VMs (control-plane, 2 workers, registry)
```

The first run will take 10-15 minutes (downloading box, provisioning).

### 2. Verify VMs are Running

```bash
vagrant status
```

Expected output:
```
k3s-control      running (vmware_desktop)
k3s-worker1      running (vmware_desktop)
k3s-worker2      running (vmware_desktop)
registry-vm      running (vmware_desktop)
```

### 3. SSH into Control-Plane

```bash
vagrant ssh k3s-control
```

## Next Steps

Once VMs are running, proceed to **Ansible playbooks** to:
1. Install K3s on control-plane and workers
2. Set up local Docker registry
3. Build and deploy Online Boutique

- **Step-by-step (Vagrant + Ansible):** [../docs/QUICKSTART-VAGRANT-ANSIBLE.md](../docs/QUICKSTART-VAGRANT-ANSIBLE.md)
- **Full on-prem guide:** [../../docs/on-prem-deployment.md](../../docs/on-prem-deployment.md)

## Network Configuration

- **Bridged network**: `VMnet8` by default (`VMWARE_BRIDGE` to override)
- **Control-plane**: `192.168.1.210`
- **Worker 1**: `192.168.1.211`
- **Worker 2**: `192.168.1.212`
- **Registry VM**: `192.168.1.220` (`registry.local` in `/etc/hosts` on each VM)
- **Ingress / UI host entry (shared)**: `192.168.1.210` → `boutique.internal` (control plane; add the same line on your **PC** if you browse by hostname)

## Troubleshooting

### VMs fail to start with VMware error
- Check that VMware Desktop is installed and licensed
- Try switching to VirtualBox: `VAGRANT_DEFAULT_PROVIDER=virtualbox vagrant up`

### "Could not find a suitable provider"
- VMware plugin not installed: `vagrant plugin install vagrant-vmware-desktop`
- Or use VirtualBox as fallback

### SSH connection refused
- Wait 30-60 seconds for VMs to finish booting
- Check: `vagrant ssh k3s-control -- echo "OK"`

## Cleanup

```bash
vagrant destroy -f    # Destroys all VMs (WARNING: no confirmation)
```

## File Layout

```
vagrant/
├── Vagrantfile              # Primary VM provisioning config
├── ansible-ssh-env.sh       # Sources SSH key env for Ansible (insert_key=false)
└── README.md                # This file
```
