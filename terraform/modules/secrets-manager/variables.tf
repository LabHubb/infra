variable "name_prefix" {
  type        = string
  description = "Prefix path for the secret name (e.g. labhub-dev)"
}

variable "secret_name" {
  type        = string
  default     = "app-secrets"
  description = "Name suffix for the single combined secret (e.g. 'app-secrets' → labhub-dev/app-secrets)"
}

variable "description" {
  type        = string
  default     = "Application secrets – managed by Terraform"
  description = "Description shown in the AWS Secrets Manager console"
}

variable "secrets" {
  type = map(object({
    value       = string
    description = optional(string, "")
  }))
  description = "Map of secret key → value. All keys are combined into one JSON secret. Keys become env var names inside ECS containers."
}

variable "recovery_window_in_days" {
  type        = number
  default     = 7
  description = "Days before a deleted secret can be permanently deleted (0 = immediate)"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to the secret"
}
