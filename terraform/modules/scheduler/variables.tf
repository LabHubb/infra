variable "name_prefix" {
  type        = string
  description = "Prefix for all resource names (e.g. myapp-dev)"
}

variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "aws_account_id" {
  type        = string
  description = "AWS account ID – used to build ARNs for IAM policy"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to all resources"
}

# ── ECS ──────────────────────────────────────────────────────────────────────

variable "ecs_cluster_name" {
  type        = string
  description = "ECS cluster name"
}

variable "ecs_services" {
  type = map(object({
    service_name  = string
    desired_count = number
  }))
  description = "Map of ECS services with their original desired_count to restore at start time"
}

# ── ASG ───────────────────────────────────────────────────────────────────────

variable "asg_name" {
  type        = string
  description = "Auto Scaling Group name for ECS EC2 nodes"
}

variable "asg_min_size" {
  type        = number
  default     = 1
  description = "ASG minimum size to restore at start time"
}

variable "asg_max_size" {
  type        = number
  default     = 2
  description = "ASG maximum size (kept constant)"
}

variable "asg_desired_capacity" {
  type        = number
  default     = 1
  description = "ASG desired capacity to restore at start time"
}

# ── RDS ───────────────────────────────────────────────────────────────────────

variable "rds_identifier" {
  type        = string
  description = "RDS DB instance identifier"
}

# ── ElastiCache ───────────────────────────────────────────────────────────────

variable "redis_replication_group_id" {
  type        = string
  description = "ElastiCache replication group ID"
}
