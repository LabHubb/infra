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

variable "log_group_name" {
  type        = string
  description = "CloudWatch log group name"
}

variable "service" {
  type = object({
    name              = string
    container_port    = number
    # host_port is always set equal to container_port (fixed static mapping).
    # In dev:  nginx upstream → 127.0.0.1:<container_port>  (must be unique per service)
    # In prod: ALB target group uses container_port; hostPort=container_port is fine with awsvpc or bridge+ALB.
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

variable "health_check_grace_period_seconds" {
  type        = number
  default     = 60
  description = "Seconds ECS waits before starting ALB health checks on a new task. Set high enough for your app startup time."
}

variable "task_policy_json" {
  type        = string
  default     = ""
  description = "Optional additional IAM policy JSON for the task role"
}

variable "s3_bucket_arns" {
  type        = list(string)
  default     = []
  description = "List of S3 bucket ARNs the ECS task role is allowed to read/write. Leave empty to skip S3 policy."
}

variable "secrets_manager_secret_names" {
  type        = list(string)
  default     = []
  description = "List of Secrets Manager secret names (e.g. labhub-dev/app-secrets) the ECS task role can read at runtime. A wildcard ARN is constructed internally so the random suffix AWS appends is handled automatically."
}


variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to all resources"
}
