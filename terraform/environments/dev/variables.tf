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
  description = "Private subnet IDs – RDS (ElastiCache no longer used in dev)"
}

variable "ami_id" {
  type        = string
  default     = null
  description = "ECS-optimized AMI ID. Leave null to auto-fetch the latest Amazon Linux 2 ECS-optimized AMI for the region."
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

variable "spot_instance_types" {
  type        = list(string)
  default     = []
  description = "Extra instance types for Spot capacity. Must be the same architecture as ami_id (x86_64)."
}

variable "on_demand_base_capacity" {
  type        = number
  default     = 0
  description = "On-Demand instances guaranteed before Spot. 0 = fully Spot; set to 1 to guarantee the node always launches."
}


variable "hosted_zone_name" {
  type        = string
  default     = ""
  description = "Route53 hosted zone domain (e.g. example.com). Only needed when enable_route53 = true."
}

variable "nginx_ec2_public_ips" {
  type        = list(string)
  default     = []
  description = "Static/Elastic public IPs of nginx EC2 nodes to register in Route53. Only needed when enable_route53 = true."
}

variable "services" {
  type = map(object({
    name                  = string
    container_port        = number # used as both containerPort and hostPort; must be unique per service in dev
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
    # Rewrite the public path_pattern down to this prefix before proxying, for
    # services whose container serves a different prefix. Used by be-admin, which
    # is exposed on /admin/api/* but serves /api/v1 (be-app already owns /api).
    # Null = pass the path through unchanged.
    upstream_path = optional(string)
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
  default     = {}
  description = "Map of service key to Route53 subdomain. Only needed when enable_route53 = true."
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

variable "redis_password" {
  type        = string
  sensitive   = true
  description = "Redis AUTH token – stored in Secrets Manager"
}

variable "jwt_secret" {
  type        = string
  sensitive   = true
  description = "JWT SECRET – stored in Secrets Manager"
}

variable "payment_client_id" {
  type        = string
  sensitive   = true
  description = "Payment client ID – stored in Secrets Manager"
}

variable "payment_api_key" {
  type        = string
  sensitive   = true
  description = "Payment API key – stored in Secrets Manager"
}

variable "payment_checksum_key" {
  type        = string
  sensitive   = true
  description = "Payment checksum key – stored in Secrets Manager"
}

variable "fcm_project_id" {
  type        = string
  sensitive   = true
  description = "Firebase Cloud Messaging project ID – stored in Secrets Manager"
}

variable "fcm_private_key" {
  type        = string
  sensitive   = true
  description = "Firebase Cloud Messaging private key – stored in Secrets Manager"
}

variable "fcm_client_email" {
  type        = string
  sensitive   = true
  description = "Firebase Cloud Messaging client email – stored in Secrets Manager"
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

variable "redis_host_override" {
  type        = string
  default     = null
  description = "Redis host to inject as REDIS_HOST when enable_redis = false (ElastiCache disabled). Set to '172.17.0.1' when running Redis as an ECS container on the same EC2 host (Docker bridge gateway)."
}

variable "enable_scheduler" {
  type        = bool
  default     = true
  description = "Enable auto stop/start scheduler for ECS, RDS and ElastiCache (dev cost saving). Requires enable_ecs and enable_postgres = true. When Redis runs as an ECS container, it is stopped automatically with the ECS services."
}

################################################################################
# Module enable/disable flags
# Set any flag to false to skip provisioning that module entirely.
#
# Dependency graph:
#   enable_nginx          → requires enable_ecs
#   enable_redis          → requires enable_ecs (ElastiCache SG ingress from ECS SG)
#   enable_redis_container→ requires enable_ecs (runs inside the existing ECS cluster)
#   enable_postgres       → requires enable_ecs (SG ingress from ECS SG)
#   enable_scheduler      → requires enable_ecs + enable_postgres
#                           (Redis container stops/starts automatically with ECS)
#   enable_ecs_services uses: enable_cloudwatch_logs, enable_secrets (optional)
#
# Dev default: enable_redis = false, enable_redis_container = true
#   Redis runs as redis:7-alpine ECS service. REDIS_HOST is auto-injected as
#   172.17.0.1 (Docker bridge gateway) into all app containers.
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
  default     = false
  description = "Enable AWS ElastiCache Redis and its security group. Set to false (default in dev) to use Redis as an ECS container instead. When enable_ecs = true, the SG ingress rule is scoped to the ECS SG."
}

variable "enable_redis_container" {
  type        = bool
  default     = true
  description = "Deploy Redis as an ECS container (redis:7-alpine) inside the existing ECS cluster. Mutually exclusive with enable_redis (ElastiCache). When true, REDIS_HOST is auto-injected as 172.17.0.1 (Docker bridge gateway). Requires enable_ecs = true."
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

