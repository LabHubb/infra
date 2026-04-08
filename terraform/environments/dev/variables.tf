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

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block – used for nginx→ECS SG ingress rule"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs – EC2 nodes placed here and get public IPs in dev"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs – RDS, ElastiCache"
}

variable "ami_id" {
  type        = string
  description = "ECS-optimized AMI ID (Amazon Linux 2)"
}

variable "instance_type" {
  type        = string
  default     = "t3a.medium"
  description = "EC2 instance type for ECS cluster nodes"
}

variable "asg_min_size" {
  type    = number
  default = 1
}

variable "asg_max_size" {
  type    = number
  default = 2
}

variable "asg_desired_capacity" {
  type    = number
  default = 1
}

variable "spot_max_price" {
  type        = string
  default     = ""
  description = "Max Spot price per hour for ECS EC2 nodes. Empty string = on-demand price cap (recommended)."
}

variable "ssh_allowed_cidrs" {
  type        = list(string)
  default     = []
  description = "CIDRs allowed to SSH to nginx EC2 instances. Leave empty to disable SSH."
}

variable "hosted_zone_name" {
  type        = string
  description = "Route53 hosted zone domain (e.g. example.com)"
}

variable "nginx_ec2_public_ips" {
  type        = list(string)
  default     = []
  description = "Static/Elastic public IPs of nginx EC2 nodes to register in Route53. Update after first apply."
}

variable "services" {
  type = map(object({
    name                  = string
    container_port        = number
    cpu                   = number
    memory                = number
    desired_count         = number
    path_pattern          = string
    priority              = number
    health_check_path     = string
    health_check_matcher  = optional(string, "200")
    health_check_interval = optional(number, 30)
    image_tag             = string
    public                = bool
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

variable "service_hostnames" {
  type        = map(string)
  default     = {}
  description = "Map of service key to nginx server_name hostname (e.g. { be = 'api.dev.example.com' })"
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
  default     = 14
  description = "CloudWatch log retention in days"
}

variable "rds_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "redis_node_type" {
  type    = string
  default = "cache.t4g.micro"
}

variable "enable_scheduler" {
  type        = bool
  default     = true
  description = "Enable auto stop/start scheduler for ECS, RDS and ElastiCache (dev cost saving). Requires enable_ecs, enable_postgres and enable_redis = true."
}

################################################################################
# Module enable/disable flags
# Set any flag to false to skip provisioning that module entirely.
#
# Dependency graph:
#   enable_nginx     → requires enable_ecs  (nginx ASG uses ECS cluster + SG)
#   enable_redis     → requires enable_ecs  to set SG ingress rule (optional)
#   enable_postgres  → requires enable_ecs  to set SG ingress rule (optional)
#   enable_scheduler → requires enable_ecs + enable_postgres + enable_redis
#   enable_ecs_services uses: enable_cloudwatch_logs, enable_secrets (all optional)
################################################################################

variable "enable_secrets" {
  type        = bool
  default     = true
  description = "Enable Secrets Manager module (DB password + Redis token). Secrets are injected into every ECS container when enabled."
}

variable "enable_ecs" {
  type        = bool
  default     = true
  description = "Enable ECS cluster, ECS services and the ECS security group. Required by enable_nginx, enable_redis, enable_postgres for SG rules."
}

variable "enable_nginx" {
  type        = bool
  default     = true
  description = "Enable nginx reverse-proxy on EC2 (dev load balancer). Requires enable_ecs = true. Automatically disabled when enable_ecs = false."
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
  description = "Enable Route53 DNS A records pointing to nginx EC2 public IPs."
}

variable "enable_ecr" {
  type        = bool
  default     = true
  description = "Enable ECR repository creation. One repo is automatically created per service name in var.services. Set to false if repos already exist."
}

