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
  default     = "prod"
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
  default     = "10.200.0.0/16"
}

variable "subnet_control_plane_cidr" {
  description = "Control plane subnet CIDR"
  type        = string
  default     = "10.200.0.0/24"
}

variable "subnet_workers_cidr" {
  description = "Workers subnet CIDR"
  type        = string
  default     = "10.200.1.0/24"
}

variable "subnet_services_cidr" {
  description = "Services subnet CIDR"
  type        = string
  default     = "10.200.2.0/24"
}

variable "subnet_pods_cidr" {
  description = "Pods subnet CIDR"
  type        = string
  default     = "10.200.16.0/20"
}

variable "subnet_k8s_services_cidr" {
  description = "Kubernetes services subnet CIDR"
  type        = string
  default     = "10.200.32.0/22"
}

variable "subnet_connectors_cidr" {
  description = "Connectors subnet CIDR (for Twingate)"
  type        = string
  default     = "10.200.3.0/24"
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
  default     = "Standard_B1s"
}

variable "twingate_ssh_public_key" {
  description = "SSH public key for Twingate VM access (ignored if use_operations_key_vault=true)"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Management Access
# -----------------------------------------------------------------------------

variable "management_cidrs" {
  description = "CIDRs for management access (VPN, Twingate)"
  type        = list(string)
  default     = []
}

variable "custom_worker_ingress_rules" {
  description = "Extra inbound NSG rules appended to the workers NSG, so any workload can open ports declaratively. Each entry is a full NSG rule object."
  type = list(object({
    name                       = string
    priority                   = number
    direction                  = string
    access                     = string
    protocol                   = string
    source_port_range          = optional(string, "*")
    destination_port_range     = optional(string)
    destination_port_ranges    = optional(list(string))
    source_address_prefix      = optional(string)
    source_address_prefixes    = optional(list(string))
    destination_address_prefix = optional(string)
  }))
  default = []
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
# Public DNS Configuration (External services)
# Records are peer reviewed before applying.
# -----------------------------------------------------------------------------

variable "public_dns_zones" {
  description = "List of public DNS zones to create - engineers add new zones here (peer reviewed)"
  type = list(object({
    name = string # Zone name (e.g., 'example.com')
    a_records = optional(list(object({
      name    = string # Subdomain (e.g., 'api' for api.example.com, '@' for apex)
      ttl     = optional(number, 300)
      records = list(string) # List of IPv4 addresses
    })), [])
    cname_records = optional(list(object({
      name   = string # Subdomain (e.g., 'www')
      ttl    = optional(number, 300)
      record = string # Target domain
    })), [])
    txt_records = optional(list(object({
      name    = string # Subdomain (e.g., '@' for apex)
      ttl     = optional(number, 300)
      records = list(string) # TXT values
    })), [])
    mx_records = optional(list(object({
      name = string # Subdomain (e.g., '@' for apex)
      ttl  = optional(number, 300)
      records = list(object({
        preference = number
        exchange   = string
      }))
    })), [])
  }))
  default = []
}

# -----------------------------------------------------------------------------
# cert-manager Workload Identity
# -----------------------------------------------------------------------------

variable "enable_cert_manager_identity" {
  description = "Create managed identity for cert-manager DNS-01 challenges"
  type        = bool
  default     = false
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
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
