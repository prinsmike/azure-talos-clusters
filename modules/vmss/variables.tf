variable "name" {
  description = "VMSS name"
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

variable "vm_size" {
  description = "VM size"
  type        = string
  default     = "Standard_D4as_v5"
}

variable "instances" {
  description = "Number of instances"
  type        = number
  default     = 1
}

variable "zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "single_placement_group" {
  description = "Use single placement group"
  type        = bool
  default     = false
}

variable "overprovision" {
  description = "Overprovision instances"
  type        = bool
  default     = false
}

variable "upgrade_mode" {
  description = "Upgrade mode (Manual, Rolling, Automatic)"
  type        = string
  default     = "Manual"
}

variable "image_id" {
  description = "Source image ID"
  type        = string
}

variable "machine_config" {
  description = "Talos machine configuration (YAML)"
  type        = string
}

variable "os_disk_type" {
  description = "OS disk storage type"
  type        = string
  default     = "Premium_LRS"
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB"
  type        = number
  default     = 128
}

variable "subnet_id" {
  description = "Subnet ID for network interface"
  type        = string
}

variable "nsg_id" {
  description = "NSG ID for network interface"
  type        = string
}

variable "managed_identity_id" {
  description = "Managed identity ID (optional)"
  type        = string
  default     = null
}

variable "load_balancer_backend_pool_ids" {
  description = "Load balancer backend pool IDs"
  type        = list(string)
  default     = []
}

variable "enable_boot_diagnostics" {
  description = "Enable boot diagnostics"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}
