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
# NOTE: ElastiCache is not used in dev (Redis runs as an ECS container).
# This variable is kept for backwards compatibility but is not used by this module.

variable "redis_replication_group_id" {
  type        = string
  default     = ""
  description = "ElastiCache replication group ID (unused – kept for backwards compatibility)"
}

# ── One-off stop override ─────────────────────────────────────────────────────

variable "one_off_stop_at" {
  type        = string
  default     = null
  description = <<-EOT
    Optional one-off override for the daily stop, as an RFC3339 timestamp in
    var.one_off_stop_timezone (e.g. "2026-09-18T23:59:00+07:00").

    When set, ECS services and RDS stop at this time and the ASG scales to 0
    five minutes later. The recurring 18:00 GMT+7 stop is held back past this
    time, so it skips the overridden day and resumes automatically at the next
    cron match. The morning start schedules are unaffected.

    Must be in the future at apply time. Set back to null once the late session
    is over to drop the one-off schedules.
  EOT

  validation {
    condition     = var.one_off_stop_at == null ? true : can(formatdate("YYYY-MM-DD", var.one_off_stop_at))
    error_message = "one_off_stop_at must be a valid RFC3339 timestamp, e.g. 2026-09-18T23:59:00+07:00."
  }
}

variable "one_off_stop_timezone" {
  type        = string
  default     = "Asia/Ho_Chi_Minh"
  description = "IANA timezone the one_off_stop_at wall-clock time is interpreted in."
}
