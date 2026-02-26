variable "controller_ip" {
  description = "IP address of the K3s controller node"
  type        = string
  default     = "192.168.56.10"
}

variable "worker_ips" {
  description = "List of IP addresses for K3s worker nodes"
  type        = list(string)
  default     = ["192.168.56.11", "192.168.56.12"]
}

variable "ssh_user" {
  description = "SSH username for remote access"
  type        = string
  default     = "vagrant"
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key file"
  type        = string
  default     = "~/.vagrant.d/insecure_private_key"
}
