variable "cluster_name" {
  description = "Kubernetes cluster name"
  type        = string
}

variable "cluster_endpoint" {
  description = "Kubernetes API endpoint (e.g., https://10.200.2.10:6443)"
  type        = string
}

variable "talos_version" {
  description = "Talos Linux version"
  type        = string
  default     = "v1.11.5"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "v1.32.1"
}

variable "control_plane_zones" {
  description = "Availability zones for control plane nodes"
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "control_plane_subnet" {
  description = "Control plane subnet CIDR"
  type        = string
}

variable "worker_subnet" {
  description = "Worker subnet CIDR"
  type        = string
}

variable "pod_subnet" {
  description = "Pod network CIDR"
  type        = string
  default     = "10.244.0.0/16"
}

variable "service_subnet" {
  description = "Service network CIDR"
  type        = string
  default     = "10.96.0.0/12"
}

variable "dns_domain" {
  description = "Kubernetes DNS domain"
  type        = string
  default     = "cluster.local"
}

variable "install_disk" {
  description = "Disk to install Talos on"
  type        = string
  default     = "/dev/sda"
}

variable "additional_api_sans" {
  description = "Additional SANs for API server certificate"
  type        = list(string)
  default     = []
}

variable "worker_cert_sans" {
  description = "Additional SANs for worker node Talos API certificates. Include expected worker IP addresses to fix IP SAN issue with DHCP."
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# Secret Backup Configuration (ADR-0002)
# -----------------------------------------------------------------------------

variable "environment" {
  description = "Environment name (used for Key Vault secret naming)"
  type        = string
  default     = ""
}

variable "operations_key_vault_name" {
  description = "Name of the operations Key Vault used by the secrets-backup helper command"
  type        = string
  default     = "kv-talos-ops"
}
