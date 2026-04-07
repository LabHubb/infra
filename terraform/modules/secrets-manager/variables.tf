variable "name_prefix" {
  type        = string
  description = "Prefix path for secret names (e.g. myapp/dev)"
}

variable "secrets" {
  type = map(object({
    value       = string
    description = optional(string, "Managed by Terraform")
  }))
  sensitive   = true
  description = "Map of secret key to secret value + description"
}

variable "recovery_window_in_days" {
  type        = number
  default     = 7
  description = "Days before a deleted secret can be permanently deleted (0 = immediate)"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to all secrets"
}
