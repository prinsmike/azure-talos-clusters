# -----------------------------------------------------------------------------
# Required Variables
# -----------------------------------------------------------------------------

variable "azure_subscription_id" {
  description = "Azure subscription ID for this environment"
  type        = string
}

variable "management_subscription_id" {
  description = "Azure subscription ID where management resources (state storage, ACR, shared Talos image gallery) live. If empty, defaults to azure_subscription_id."
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Management Resources (management subscription)
# -----------------------------------------------------------------------------

variable "management_resource_group_name" {
  description = "Resource group holding management resources (ACR, state storage, shared Talos image gallery)"
  type        = string
  default     = "rg-talos-ops"
}

variable "container_registry_name" {
  description = "Name of the shared container registry in the management subscription"
  type        = string
  default     = "acrtalos"
}

variable "enable_acr_pull" {
  description = "Grant VMSS identities AcrPull on the shared container registry"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Environment Configuration
# -----------------------------------------------------------------------------

variable "project" {
  description = "Project prefix for resource names (must match the network-and-security layer)"
  type        = string
  default     = "talos"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "location_short" {
  description = "Short location code"
  type        = string
  default     = "eastus"
}

# -----------------------------------------------------------------------------
# Network-and-security layer resource group
# -----------------------------------------------------------------------------

variable "network_resource_group_name" {
  description = "Resource group created by the network-and-security layer"
  type        = string
  default     = "rg-talos-dev-network-eastus"
}

# -----------------------------------------------------------------------------
# Cluster Configuration
# -----------------------------------------------------------------------------

variable "cluster_name" {
  description = "Kubernetes cluster name"
  type        = string
  default     = "talos-dev"
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

# -----------------------------------------------------------------------------
# Shared Talos Image (management layer Compute Gallery, Change A)
# -----------------------------------------------------------------------------

variable "talos_gallery_name" {
  description = "Azure Compute Gallery name published by the management layer"
  type        = string
  default     = "gal_talos"
}

variable "talos_image_definition_name" {
  description = "Shared image definition name published by the management layer"
  type        = string
  default     = "talos-azure-amd64"
}

variable "talos_image_version" {
  description = "Shared image version to consume (e.g. \"1.11.5\" or \"latest\")"
  type        = string
  default     = "latest"
}

# -----------------------------------------------------------------------------
# Control Plane Configuration
# -----------------------------------------------------------------------------

variable "control_plane_vm_size" {
  description = "Control plane VM size"
  type        = string
  default     = "Standard_D2as_v5" # smaller for dev
}

variable "control_plane_os_disk_size_gb" {
  description = "Control plane OS disk size in GB"
  type        = number
  default     = 64
}

# -----------------------------------------------------------------------------
# Worker Configuration
# -----------------------------------------------------------------------------

variable "worker_vm_size" {
  description = "Worker VM size"
  type        = string
  default     = "Standard_D4as_v5"
}

variable "worker_os_disk_size_gb" {
  description = "Worker OS disk size in GB"
  type        = number
  default     = 128
}

variable "worker_instance_count" {
  description = "Number of worker instances"
  type        = number
  default     = 1 # single worker for dev
}

variable "worker_cert_sans" {
  description = "Additional SANs for worker Talos API certificates. Include expected worker IPs in the workers subnet."
  type        = list(string)
  default = [
    "10.100.1.4",
    "10.100.1.5",
    "10.100.1.6",
    "10.100.1.7",
    "10.100.1.8"
  ]
}

# -----------------------------------------------------------------------------
# Network Configuration (must match the network-and-security layer)
# -----------------------------------------------------------------------------

variable "subnet_control_plane_cidr" {
  description = "Control plane subnet CIDR"
  type        = string
  default     = "10.100.0.0/24"
}

variable "subnet_workers_cidr" {
  description = "Workers subnet CIDR"
  type        = string
  default     = "10.100.1.0/24"
}

variable "subnet_services_cidr" {
  description = "Services subnet CIDR"
  type        = string
  default     = "10.100.2.0/24"
}

variable "subnet_pods_cidr" {
  description = "Pods subnet CIDR"
  type        = string
  default     = "10.100.16.0/20"
}

variable "subnet_k8s_services_cidr" {
  description = "Kubernetes services subnet CIDR"
  type        = string
  default     = "10.100.32.0/22"
}

variable "api_server_lb_ip" {
  description = "API server load balancer IP (must be in the services subnet)"
  type        = string
  default     = "10.100.2.10"
}

# -----------------------------------------------------------------------------
# Workload Identity Federation
#
# Federated credentials bind in-cluster service accounts to the user-assigned
# identities created in the network-and-security layer. They require the OIDC
# issuer to be configured in the Talos cluster (available after bootstrap).
# -----------------------------------------------------------------------------

variable "oidc_issuer_url" {
  description = "OIDC issuer URL of the Talos cluster (required for any federation)"
  type        = string
  default     = ""
}

variable "enable_cert_manager_federation" {
  description = "Create the federated credential for the cert-manager workload identity"
  type        = bool
  default     = false
}

variable "cert_manager_service_account" {
  description = "Kubernetes service account for cert-manager"
  type        = string
  default     = "system:serviceaccount:cert-manager:cert-manager"
}

variable "enable_external_dns_federation" {
  description = "Create the federated credential for the external-dns workload identity (Change C)"
  type        = bool
  default     = false
}

variable "external_dns_service_account" {
  description = "Kubernetes service account for external-dns"
  type        = string
  default     = "system:serviceaccount:external-dns:external-dns"
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "talos-platform"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
