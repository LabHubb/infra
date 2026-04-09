project_name = "labhub"
environment  = "prod"
aws_region   = "ap-southeast-1"

# ── Networking ────────────────────────────────────────────────────────────────
vpc_id             = "vpc-0prod456789abcdef0"
public_subnet_ids  = ["subnet-prod-pub-a", "subnet-prod-pub-b"]
private_subnet_ids = ["subnet-prod-priv-a", "subnet-prod-priv-b"]

# ── ECS cluster nodes (private subnets, no public IP) ─────────────────────────
# Billing strategy: On-Demand covered by a Compute Savings Plan.
# Purchase a 1-year Compute Savings Plan in the AWS Billing console that
# covers at least: asg_min_size × t3a.medium on-demand hourly rate.
# Savings Plans apply automatically to all EC2 usage regardless of instance
# family/region, giving up to 66% discount with no Terraform changes needed.
#
# ami_id is auto-fetched from SSM Parameter Store (latest ECS-optimized Amazon Linux 2).
# Override only if you need a specific AMI: ami_id = "ami-xxxxxxxxxxxxxxxxx"
instance_type        = "t3a.medium"
asg_min_size         = 1
asg_max_size         = 10
asg_desired_capacity = 1

# ── ALB / TLS ─────────────────────────────────────────────────────────────────
acm_certificate_arn            = "arn:aws:acm:ap-southeast-1:YOUR_ACCOUNT_ID:certificate/prod-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
enable_alb_deletion_protection = true

# Seconds ECS waits after a container starts before ALB begins health checking
# against /api/v1/health. Increase if app startup (DB connect, cache warm-up)
# takes longer than this value.
health_check_grace_period_seconds = 60

# ── DNS ───────────────────────────────────────────────────────────────────────
hosted_zone_name = "example.com"

service_dns_map = {
  be = {
    subdomain = "api"
  }
  fe_admin = {
    subdomain = "admin"
  }
  fe_customer = {
    subdomain = "app"
  }
}

# ── ECS Services ──────────────────────────────────────────────────────────────
# Only specify image_tag (e.g. "latest", "v1.2.3").
# The full ECR URL is auto-constructed in main.tf using your AWS account ID + region.
#
# The following environment variables are automatically injected into ALL services
# from module outputs – do NOT add them manually here:
#   DATABASE_HOST, DATABASE_PORT, DATABASE_USER, DATABASE_NAME  → from RDS module
#   REDIS_HOST, REDIS_PORT                                       → from ElastiCache module
services = {
  be-app = {
    name                  = "be-app"
    container_port        = 8080
    cpu                   = 1024
    memory                = 2048
    desired_count         = 2
    path_pattern          = "/api/*"
    priority              = 10
    health_check_path     = "/api/v1/health"  # ALB health check endpoint
    health_check_matcher  = "200"             # only HTTP 200 is considered healthy
    health_check_interval = 30               # seconds between checks
    image_tag             = "latest"
    public                = false

    environment_variables = [
      { name = "DATABASE_SSLMODE",     value = "disable" }
    ]
  }

  # fe_admin = {
  #   name              = "fe-admin"
  #   container_port    = 3000
  #   cpu               = 512
  #   memory            = 1024
  #   desired_count     = 2
  #   path_pattern      = "/admin/*"
  #   priority          = 20
  #   health_check_path = "/"
  #   image_tag         = "latest"
  #   public            = true
  #   environment_variables = [
  #     { name = "APP_ENV",  value = "production" },
  #     { name = "APP_PORT", value = "3000" },
  #   ]
  # }
  #
  # fe_customer = {
  #   name              = "fe-customer"
  #   container_port    = 3000
  #   cpu               = 512
  #   memory            = 1024
  #   desired_count     = 2
  #   path_pattern      = "/*"
  #   priority          = 30
  #   health_check_path = "/"
  #   image_tag         = "latest"
  #   public            = true
  #   environment_variables = [
  #     { name = "APP_ENV",  value = "production" },
  #     { name = "APP_PORT", value = "3000" },
  #   ]
  # }
}

# ── Storage ───────────────────────────────────────────────────────────────────
storage = {
  redis_name    = "redis"
  postgres_name = "postgres"
}

# ── S3 Buckets ────────────────────────────────────────────────────────────────
# Use 'name' for a fully custom bucket name (ignores name_prefix + suffix).
# Use 'suffix' to auto-build: labhub-prod-<suffix>.
#
# access options:
#   "private"     → Block Public Access ON  (default – recommended for app data)
#   "public-read" → Block Public Access OFF, public GetObject policy applied
#                   (use for static assets served directly from S3 or CloudFront)
s3_buckets = {
  bucket_001 = {
    name               = "aws-sg-labhub-prod-s3-bucket-001"
    access             = "public-read"
    versioning_enabled = true
    sse_algorithm      = "AES256"

    # Lifecycle: move old versions to cheaper storage, delete after 2 years (prod)
    noncurrent_version_transition_ia_days      = 30
    noncurrent_version_transition_glacier_days = 90
    noncurrent_version_expiration_days         = 730
    abort_incomplete_multipart_days            = 7

    cors_allowed_origins = ["https://app.example.com", "https://admin.example.com"]
    cors_allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    cors_allowed_headers = ["*"]
    cors_expose_headers  = ["ETag"]
    cors_max_age_seconds = 3600

    website_enabled = false
  }

  bucket_002 = {
    name               = "aws-sg-labhub-prod-s3-bucket-002"
    access             = "private"
    versioning_enabled = true
    sse_algorithm      = "AES256"

    # Lifecycle: move old versions to cheaper storage, delete after 2 years (prod)
    noncurrent_version_transition_ia_days      = 30
    noncurrent_version_transition_glacier_days = 90
    noncurrent_version_expiration_days         = 730
    abort_incomplete_multipart_days            = 7

    # Allow the frontend origin to call the S3 pre-signed URL API directly
    cors_allowed_origins = ["https://app.example.com", "https://admin.example.com"]
    cors_allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    cors_allowed_headers = ["*"]
    cors_expose_headers  = ["ETag"]
    cors_max_age_seconds = 3600

    website_enabled = false
  }
}

# ── Database ──────────────────────────────────────────────────────────────────
rds_instance_class = "db.t4g.small"
db_name            = "myapp"
db_username        = "myapp_admin"
# db_password      → set via: export TF_VAR_db_password="..."

# ── Redis ─────────────────────────────────────────────────────────────────────
redis_node_type = "cache.t4g.small"
# redis_auth_token → set via: export TF_VAR_redis_auth_token="..."

# ── Observability ─────────────────────────────────────────────────────────────
log_retention_days = 90

# ── Module enable/disable flags ───────────────────────────────────────────────
# Set any flag to false to skip creating that module entirely.
# Useful for staged rollouts (e.g. bring up ECS before enabling ALB / Route53).
#
# Dependency rules (cross-module guards are enforced in main.tf):
#   enable_alb      ECS SG ingress from ALB only when enable_alb = true
#   enable_ecs      required for enable_alb ECS SG ingress rule
#   enable_redis    SG ingress from ECS only when enable_ecs = true
#   enable_postgres SG ingress from ECS only when enable_ecs = true
#   enable_route53  ALB alias records only created when enable_alb = true
#   enable_ecs_services uses enable_cloudwatch_logs + enable_secrets + enable_alb (all optional)

enable_secrets         = false  # ← set false to destroy labhub-prod/app-secrets
enable_ecs             = true
enable_alb             = true   # requires enable_ecs = true for ECS SG ingress rule
enable_redis           = true
enable_postgres        = true
enable_s3              = true
enable_cloudwatch_logs = true
enable_route53         = true   # ALB alias records only created when enable_alb = true
enable_ecr             = false  # ← set false to destroy all ECR repositories

