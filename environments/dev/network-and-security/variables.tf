# -----------------------------------------------------------------------------
# Required Variables
# -----------------------------------------------------------------------------

variable "azure_subscription_id" {
  description = "Azure subscription ID for this environment"
  type        = string
}

variable "management_subscription_id" {
  description = "Azure subscription ID where management-layer resources (state storage, ACR, Operations Key Vault) are deployed. If not set, defaults to azure_subscription_id."
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Environment Configuration
# -----------------------------------------------------------------------------

variable "project" {
  description = "Project prefix for resource names"
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
# Network Configuration
# -----------------------------------------------------------------------------

variable "vnet_address_space" {
  description = "VNet address space"
  type        = string
  default     = "10.100.0.0/16"
}

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

variable "subnet_connectors_cidr" {
  description = "Connectors subnet CIDR (for Twingate ACI - deprecated)"
  type        = string
  default     = "10.100.3.0/24"
}

variable "subnet_connector_vms_cidr" {
  description = "Connector VMs subnet CIDR (for Twingate VMs)"
  type        = string
  default     = "10.100.4.0/24"
}

# -----------------------------------------------------------------------------
# Operations Key Vault (from Management)
# -----------------------------------------------------------------------------

variable "use_operations_key_vault" {
  description = "Read operational secrets from the Management Key Vault instead of CLI variables"
  type        = bool
  default     = false
}

variable "operations_key_vault_name" {
  description = "Name of the operations Key Vault (from the Management layer)"
  type        = string
  default     = "kv-talos-ops"
}

variable "operations_key_vault_resource_group" {
  description = "Resource group containing the operations Key Vault"
  type        = string
  default     = "rg-talos-ops"
}

# -----------------------------------------------------------------------------
# Twingate Configuration
# -----------------------------------------------------------------------------

variable "twingate_api_token" {
  description = "Twingate API token (ignored if use_operations_key_vault=true)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "twingate_network" {
  description = "Twingate network name (ignored if use_operations_key_vault=true)"
  type        = string
  default     = ""
}

variable "enable_twingate" {
  description = "Enable Twingate connector deployment"
  type        = bool
  default     = false
}

variable "twingate_connector_count" {
  description = "Number of Twingate connectors to deploy (2+ for HA)"
  type        = number
  default     = 2
}

variable "twingate_vm_size" {
  description = "Azure VM size for Twingate connectors (B-series recommended)"
  type        = string
  default     = "Standard_B1ls"
}

variable "twingate_ssh_public_key" {
  description = "SSH public key for Twingate VM access (ignored if use_operations_key_vault=true)"
  type        = string
  default     = ""
}

variable "twingate_resources" {
  description = "List of Twingate resources (network addresses) to create for access"
  type = list(object({
    name    = string
    address = string # IP, CIDR, FQDN, or DNS zone
  }))
  default = []
}

variable "twingate_group_ids" {
  description = "List of Twingate group IDs to grant access to resources"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# Management Access
# -----------------------------------------------------------------------------

variable "management_cidrs" {
  description = "CIDRs for management access (VPN, Twingate)"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# IAM Configuration
# -----------------------------------------------------------------------------

variable "use_least_privilege_roles" {
  description = "Use custom least-privilege roles instead of broad built-in roles (VM Contributor, Network Contributor)"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Private DNS Configuration (Internal services via Twingate)
# -----------------------------------------------------------------------------

variable "private_dns_zone_name" {
  description = "Private DNS zone name for internal services (e.g., int.example.com)"
  type        = string
  default     = ""
}

variable "private_dns_a_records" {
  description = "A records for private DNS zone - engineers add services here"
  type = list(object({
    name    = string # Subdomain (e.g., 'api' for api.int.example.com)
    ttl     = optional(number, 300)
    records = list(string) # List of IPv4 addresses
  }))
  default = []
}

variable "private_dns_cname_records" {
  description = "CNAME records for private DNS zone - engineers add aliases here"
  type = list(object({
    name   = string # Subdomain (e.g., 'www' for www.int.example.com)
    ttl    = optional(number, 300)
    record = string # Target domain
  }))
  default = []
}

# -----------------------------------------------------------------------------
# vWAN Connection (Optional)
# -----------------------------------------------------------------------------

variable "enable_vwan_connection" {
  description = "Connect VNet to management vWAN Hub"
  type        = bool
  default     = false
}

variable "vwan_hub_id" {
  description = "vWAN Hub ID to connect to (required if enable_vwan_connection=true)"
  type        = string
  default     = ""
}

variable "vwan_internet_security_enabled" {
  description = "Route internet traffic through vWAN firewall"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "talos-platform"
    CostCenter  = "platform-ops"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
