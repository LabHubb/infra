variable "project_name" {
  type        = string
  description = "Project name used as prefix for all resources"
}

variable "environment" {
  type        = string
  description = "Environment name (dev, stg, prod)"
}
