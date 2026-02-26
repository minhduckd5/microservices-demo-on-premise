terraform {
  required_version = ">= 1.7"
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# ── K3s Controller ──────────────────────────────────────────────
resource "null_resource" "k3s_controller" {
  connection {
    type        = "ssh"
    host        = var.controller_ip
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "curl -sfL https://get.k3s.io | sh -",
      "until [ -f /var/lib/rancher/k3s/server/node-token ]; do sleep 2; done",
      "echo 'K3s controller ready'",
    ]
  }
}

data "null_data_source" "k3s_token" {
  depends_on = [null_resource.k3s_controller]

  inputs = {
    # Token is read out-of-band via ansible; this is a placeholder for the path
    token_path = "/var/lib/rancher/k3s/server/node-token"
  }
}

# ── K3s Workers ─────────────────────────────────────────────────
resource "null_resource" "k3s_workers" {
  for_each = toset(var.worker_ips)

  depends_on = [null_resource.k3s_controller]

  connection {
    type        = "ssh"
    host        = each.value
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "curl -sfL https://get.k3s.io | K3S_URL=https://${var.controller_ip}:6443 K3S_TOKEN=$(ssh -i ${var.ssh_private_key_path} -o StrictHostKeyChecking=no ${var.ssh_user}@${var.controller_ip} 'sudo cat /var/lib/rancher/k3s/server/node-token') sh -",
      "echo 'K3s worker joined'",
    ]
  }
}
