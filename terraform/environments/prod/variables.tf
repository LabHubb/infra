variable "project_name" {
  type        = string
  description = "Project name used as a prefix for all resources"
}

variable "environment" {
  type        = string
  description = "Environment name (dev, prod)"
}

variable "aws_region" {
  type        = string
  description = "AWS region to deploy into"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs (used by the ALB)"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs (ECS nodes, RDS, ElastiCache)"
}

variable "ami_id" {
  type        = string
  description = "ECS-optimized AMI ID for EC2 launch template"
}

variable "instance_type" {
  type        = string
  default     = "t3a.medium"
  description = "EC2 instance type for ECS cluster nodes"
}

variable "asg_min_size" {
  type    = number
  default = 2
}

variable "asg_max_size" {
  type    = number
  default = 10
}

variable "asg_desired_capacity" {
  type    = number
  default = 3
}

variable "acm_certificate_arn" {
  type        = string
  description = "ACM certificate ARN for the ALB HTTPS listener"
}

variable "enable_alb_deletion_protection" {
  type    = bool
  default = true
}

variable "hosted_zone_name" {
  type        = string
  description = "Route53 hosted zone domain (e.g. example.com)"
}

variable "services" {
  type = map(object({
    name              = string
    container_port    = number
    cpu               = number
    memory            = number
    desired_count     = number
    path_pattern      = string
    priority          = number
    health_check_path = string
    image_tag         = string
    public            = bool
    environment_variables = optional(list(object({
      name  = string
      value = string
    })), [])
  }))
  description = "Map of ECS services to deploy"
}

variable "service_dns_map" {
  type = map(object({
    subdomain = string
  }))
  description = "Map of service key to Route53 subdomain"
}

variable "storage" {
  type = object({
    redis_name    = string
    postgres_name = string
  })
  description = "Names for Redis and Postgres resources"
}

variable "s3_buckets" {
  description = "Map of S3 bucket configurations. Each key becomes a short identifier."
  type = map(object({
    name                                       = optional(string, null)
    suffix                                     = optional(string, "")
    access                                     = optional(string, "private")
    versioning_enabled                         = optional(bool, true)
    sse_algorithm                              = optional(string, "AES256")
    kms_master_key_id                          = optional(string, null)
    noncurrent_version_transition_ia_days      = optional(number, 30)
    noncurrent_version_transition_glacier_days = optional(number, 90)
    noncurrent_version_expiration_days         = optional(number, 365)
    abort_incomplete_multipart_days            = optional(number, 7)
    cors_allowed_origins                       = optional(list(string), [])
    cors_allowed_methods                       = optional(list(string), ["GET", "PUT", "POST", "DELETE", "HEAD"])
    cors_allowed_headers                       = optional(list(string), ["*"])
    cors_expose_headers                        = optional(list(string), [])
    cors_max_age_seconds                       = optional(number, 3600)
    website_enabled                            = optional(bool, false)
    website_index_page                         = optional(string, "index.html")
    website_error_page                         = optional(string, "error.html")
  }))
  default = {}
}

variable "db_name" {
  type        = string
  description = "PostgreSQL database name"
}

variable "db_username" {
  type        = string
  description = "PostgreSQL master username"
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "PostgreSQL master password – stored in Secrets Manager"
}

variable "redis_auth_token" {
  type        = string
  sensitive   = true
  description = "Redis AUTH token – stored in Secrets Manager"
}

variable "log_retention_days" {
  type        = number
  default     = 90
  description = "CloudWatch log retention in days"
}

variable "rds_instance_class" {
  type    = string
  default = "db.t4g.small"
}

variable "redis_node_type" {
  type    = string
  default = "cache.t4g.small"
}

################################################################################
# Module enable/disable flags
# Set any flag to false to skip provisioning that module entirely.
#
# Dependency graph:
#   enable_alb      → requires enable_ecs  (ECS SG ingress rule from ALB SG)
#   enable_ecs      → requires enable_alb  to attach target groups (optional)
#   enable_redis    → requires enable_ecs  to set SG ingress rule (optional)
#   enable_postgres → requires enable_ecs  to set SG ingress rule (optional)
#   enable_route53  → requires enable_alb  to create alias A records (optional)
#   enable_ecs_services uses: enable_cloudwatch_logs, enable_secrets, enable_alb (all optional)
################################################################################

variable "enable_secrets" {
  type        = bool
  default     = true
  description = "Enable Secrets Manager module (DB password + Redis token). Secrets are injected into every ECS container when enabled."
}

variable "enable_ecs" {
  type        = bool
  default     = true
  description = "Enable ECS cluster, ECS services and the ECS security group. Required by enable_alb, enable_redis, enable_postgres for SG rules."
}

variable "enable_alb" {
  type        = bool
  default     = true
  description = "Enable ALB, ALB SG and per-service target groups. Requires enable_ecs = true for the ECS SG ingress rule."
}

variable "enable_redis" {
  type        = bool
  default     = true
  description = "Enable ElastiCache Redis and its security group. When enable_ecs = true, the SG ingress rule is scoped to the ECS SG."
}

variable "enable_postgres" {
  type        = bool
  default     = true
  description = "Enable RDS PostgreSQL and its security group. When enable_ecs = true, the SG ingress rule is scoped to the ECS SG."
}

variable "enable_s3" {
  type        = bool
  default     = true
  description = "Enable S3 file-storage bucket."
}

variable "enable_cloudwatch_logs" {
  type        = bool
  default     = true
  description = "Enable CloudWatch Log Groups for all ECS services. When false, ECS services fall back to a default log group path."
}

variable "enable_route53" {
  type        = bool
  default     = true
  description = "Enable Route53 DNS alias records. When enable_alb = true, records point to the ALB. When enable_alb = false, records are skipped (empty alb_dns_name)."
}

variable "enable_ecr" {
  type        = bool
  default     = true
  description = "Enable ECR repository creation. One repo is automatically created per service name in var.services. Set to false if repos already exist."
}

