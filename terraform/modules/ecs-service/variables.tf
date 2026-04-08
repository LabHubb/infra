variable "name_prefix" {
  type        = string
  description = "Prefix for all resource names (project-env)"
}

variable "project_name" {
  type        = string
  description = "Project name – used to build task definition and service name"
}

variable "environment" {
  type        = string
  description = "Environment name (dev, prod) – used to build task definition and service name"
}

variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "cluster_id" {
  type        = string
  description = "ECS cluster ID"
}

variable "capacity_provider_name" {
  type        = string
  description = "ECS capacity provider name"
}

variable "target_group_arn" {
  type        = string
  default     = ""
  description = "ALB target group ARN for this service. Leave empty in dev (no ALB)."
}

variable "secret_arns" {
  type        = map(string)
  default     = {}
  description = "Map of env-var name to Secrets Manager secret ARN. Injected into the container as secrets."
}

variable "log_group_name" {
  type        = string
  description = "CloudWatch log group name"
}

variable "service" {
  type = object({
    name              = string
    container_port    = number
    cpu               = number
    memory            = number
    desired_count     = number
    path_pattern      = string
    priority          = number
    health_check_path = string
    image             = string
    public            = bool
    environment_variables = optional(list(object({
      name  = string
      value = string
    })), [])
  })
  description = "Service configuration object"
}

variable "environment_variables" {
  type = list(object({
    name  = string
    value = string
  }))
  default     = []
  description = "Environment variables injected into the container"
}

variable "task_policy_json" {
  type        = string
  default     = ""
  description = "Optional additional IAM policy JSON for the task role"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to all resources"
}
