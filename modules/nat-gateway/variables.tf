variable "name" {
  description = "NAT gateway name"
  type        = string
}

variable "public_ip_name" {
  description = "Public IP name for NAT gateway"
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

variable "zones" {
  description = "Availability zones for public IP"
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "idle_timeout_in_minutes" {
  description = "Idle timeout in minutes"
  type        = number
  default     = 10
}

variable "subnet_ids" {
  description = "Map of subnet name to subnet ID for NAT gateway association"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}
