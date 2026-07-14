# -----------------------------------------------------------------------------
# Required Variables
# -----------------------------------------------------------------------------

variable "name" {
  description = "Name prefix for resources"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the connector VMs"
  type        = string
}

variable "twingate_network_name" {
  description = "Name for the Twingate remote network"
  type        = string
}

variable "twingate_account" {
  description = "Twingate account name (the subdomain from yourcompany.twingate.com)"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
}

# -----------------------------------------------------------------------------
# VM Configuration
# -----------------------------------------------------------------------------

variable "connector_count" {
  description = "Number of connectors to deploy (2+ recommended for HA)"
  type        = number
  default     = 2
}

variable "vm_size" {
  description = "Azure VM size for connectors (B-series recommended for cost efficiency)"
  type        = string
  default     = "Standard_B1ls"
}

variable "admin_username" {
  description = "Admin username for VMs"
  type        = string
  default     = "azureuser"
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB"
  type        = number
  default     = 30
}

variable "os_disk_type" {
  description = "OS disk storage account type"
  type        = string
  default     = "Standard_LRS"
}

variable "image_publisher" {
  description = "VM image publisher"
  type        = string
  default     = "Canonical"
}

variable "image_offer" {
  description = "VM image offer"
  type        = string
  default     = "0001-com-ubuntu-server-jammy"
}

variable "image_sku" {
  description = "VM image SKU"
  type        = string
  default     = "22_04-lts-gen2"
}

variable "image_version" {
  description = "VM image version"
  type        = string
  default     = "latest"
}

variable "connector_image" {
  description = "Twingate connector container image"
  type        = string
  default     = "twingate/connector:latest"
}

# -----------------------------------------------------------------------------
# Optional
# -----------------------------------------------------------------------------

variable "enable_auto_updates" {
  description = "Enable automatic security updates via unattended-upgrades"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# Twingate Resources (Network Access)
# -----------------------------------------------------------------------------

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
