output "kubeconfig_path" {
  description = "Path to the K3s kubeconfig on the controller node"
  value       = "/etc/rancher/k3s/k3s.yaml"
}

output "k3s_token" {
  description = "Path to the K3s join token on the controller node (read via SSH)"
  value       = "/var/lib/rancher/k3s/server/node-token"
  sensitive   = true
}

output "controller_ip" {
  description = "IP address of the K3s controller node"
  value       = var.controller_ip
}

output "worker_ips" {
  description = "IP addresses of K3s worker nodes"
  value       = var.worker_ips
}
