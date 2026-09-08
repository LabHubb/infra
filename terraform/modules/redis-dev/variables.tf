variable "name_prefix" {
  type        = string
  description = "Prefix for all resource names (project-env)"
}

variable "project_name" {
  type        = string
  description = "Project name – used to build task definition and service names"
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
  description = "ECS cluster ID to register the Redis service into"
}

variable "capacity_provider_name" {
  type        = string
  description = "ECS capacity provider name to schedule the Redis task on"
}

variable "redis_image" {
  type        = string
  default     = "redis:7-alpine"
  description = "Redis Docker image to use. Defaults to redis:7-alpine (Docker Hub)."
}

variable "redis_port" {
  type        = number
  default     = 6379
  description = "Redis port – published as both containerPort and hostPort on the EC2 host."
}

variable "redis_password" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Optional Redis AUTH password. When non-empty, Redis starts with '--requirepass <password>'. Leave empty (default) for no-auth, which is the recommended setting for dev."
}

variable "cpu" {
  type        = number
  default     = 128
  description = "CPU units for the Redis container"
}

variable "memory" {
  type        = number
  default     = 256
  description = "Memory (MiB) for the Redis container"
}

variable "log_retention_days" {
  type        = number
  default     = 14
  description = "CloudWatch log retention in days for Redis logs"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to all resources"
}

