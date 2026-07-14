variable "environment" {
  description = "Environment name (used for role naming)"
  type        = string
}

variable "scope" {
  description = "Scope for the role definition (typically resource group ID)"
  type        = string
}
