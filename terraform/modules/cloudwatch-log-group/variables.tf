variable "project_name" {
  type        = string
  description = "Project name used in log group path"
}

variable "environment" {
  type        = string
  description = "Environment name used in log group path"
}

variable "services" {
  type = map(object({
    name = string
  }))
  description = "Map of service key to service config (only name is used here)"
}

variable "retention_in_days" {
  type        = number
  default     = 30
  description = "CloudWatch log retention in days"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to all log groups"
}
