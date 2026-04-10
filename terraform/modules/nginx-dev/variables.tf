variable "name_prefix" {
  type        = string
  description = "Prefix for all resource names"
}

variable "project_name" {
  type        = string
  description = "Project name used in task definition family and service name"
}

variable "environment" {
  type        = string
  description = "Environment name (dev)"
}

variable "aws_region" {
  type        = string
  description = "AWS region for CloudWatch log configuration"
}

variable "ecs_cluster_id" {
  type        = string
  description = "ECS cluster ID to register the nginx service into"
}

variable "capacity_provider_name" {
  type        = string
  description = "ECS capacity provider name to schedule the nginx task on"
}

variable "log_retention_days" {
  type        = number
  default     = 14
  description = "CloudWatch log retention in days for nginx logs"
}

variable "services" {
  type = list(object({
    name           = string
    container_port = number
    path_pattern   = string
  }))
  description = "List of services nginx will proxy to via 127.0.0.1:<container_port>. Each service must use a unique container_port."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to all resources"
}
