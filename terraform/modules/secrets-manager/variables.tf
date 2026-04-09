variable "project_name" {
  type        = string
  description = "Project name – used to build the secret name: {project_name}-{environment}/{secret_name}"
}

variable "environment" {
  type        = string
  description = "Environment name (dev, prod) – used to build the secret name"
}

variable "secret_name" {
  type        = string
  default     = "app-secrets"
  description = "Secret name suffix. Full name will be: {project_name}-{environment}/{secret_name}"
}

variable "description" {
  type        = string
  default     = "Application secrets - managed by Terraform"
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
