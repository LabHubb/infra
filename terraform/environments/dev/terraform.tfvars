project_name = "labhub"
environment  = "dev"
aws_region   = "ap-southeast-1"

# ── Networking ────────────────────────────────────────────────────────────────
vpc_id             = "vpc-0edcb9983676899a7"
vpc_cidr           = "172.31.0.0/16"
# ECS EC2 + nginx use only 1 subnet (ap-southeast-1a) to keep dev simple and cheap.
public_subnet_ids  = ["subnet-004654dc97acf9435"]
# RDS and ElastiCache require at least 2 subnets in different AZs for their subnet groups.
# We still deploy the DB instances in 1 AZ but the subnet group must span 2 AZs.
private_subnet_ids = ["subnet-004654dc97acf9435", "subnet-06fd6a05ad6f7df9c"]

# ── ECS / nginx EC2 nodes ─────────────────────────────────────────────────────
# ami_id is auto-fetched from SSM Parameter Store (latest ECS-optimized Amazon Linux 2).
# Override only if you need a specific AMI: ami_id = "ami-xxxxxxxxxxxxxxxxx"
instance_type        = "t3a.small"  # 1 vCPU, 2GB RAM, AMD
asg_min_size         = 1
asg_max_size         = 1
asg_desired_capacity = 1

# Spot instances – saves ~70% vs on-demand in dev.
# spot_max_price = ""  means AWS caps the price at the current on-demand rate,
# so you are never charged more than on-demand, but you still benefit from the
# lower Spot market price. Set an explicit price (e.g. "0.05") to bid lower.
spot_max_price = ""

# SSH is handled via AWS Systems Manager (SSM) Session Manager.
# No port 22 or SSH key needed. Connect via: AWS Console > SSM > Session Manager

# ── DNS ───────────────────────────────────────────────────────────────────────
hosted_zone_name = "example.com"

# After first apply, note the EC2 public IPs (or assign Elastic IPs) and fill in:
nginx_ec2_public_ips = [] # e.g. ["13.250.x.x"]

service_dns_map = {
  be = {
    subdomain = "api.dev"
  }
  fe_admin = {
    subdomain = "admin.dev"
  }
  fe_customer = {
    subdomain = "app.dev"
  }
}

# Nginx server_name per service (must match DNS records above)
service_hostnames = {
  be          = "api.dev.example.com"
  fe_admin    = "admin.dev.example.com"
  fe_customer = "app.dev.example.com"
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
    cpu                   = 256
    memory                = 512
    desired_count         = 1
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
  #
  # fe_admin = {
  #   name              = "fe-admin"
  #   container_port    = 3000
  #   cpu               = 256
  #   memory            = 512
  #   desired_count     = 1
  #   path_pattern      = "/admin/*"
  #   priority          = 20
  #   health_check_path = "/"
  #   image_tag         = "latest"
  #   public            = true
  #   environment_variables = [
  #     { name = "APP_ENV",  value = "development" },
  #     { name = "APP_PORT", value = "3000" },
  #   ]
  # }
  #
  # fe_customer = {
  #   name              = "fe-customer"
  #   container_port    = 3000
  #   cpu               = 256
  #   memory            = 512
  #   desired_count     = 1
  #   path_pattern      = "/*"
  #   priority          = 30
  #   health_check_path = "/"
  #   image_tag         = "latest"
  #   public            = true
  #   environment_variables = [
  #     { name = "APP_ENV",  value = "development" },
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
# Use 'suffix' to auto-build: labhub-dev-<suffix>.
#
# access options:
#   "private"     → Block Public Access ON  (default – recommended for app data)
#   "public-read" → Block Public Access OFF, public GetObject policy applied
#                   (use for static assets served directly from S3 or CloudFront)
s3_buckets = {
  bucket_001 = {
    name               = "aws-sg-labhub-nonprod-s3-bucket-001"
    access             = "public-read"
    versioning_enabled = true
    sse_algorithm      = "AES256"

    noncurrent_version_transition_ia_days      = 30
    noncurrent_version_transition_glacier_days = 90
    noncurrent_version_expiration_days         = 365
    abort_incomplete_multipart_days            = 7

    cors_allowed_origins = ["*"]
    cors_allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    cors_allowed_headers = ["*"]
    cors_expose_headers  = ["ETag"]
    cors_max_age_seconds = 3600

    website_enabled = false
  }

  bucket_002 = {
    name               = "aws-sg-labhub-nonprod-s3-bucket-002"
    access             = "private"
    versioning_enabled = true
    sse_algorithm      = "AES256"

    # Lifecycle: move old versions to cheaper storage, delete after 1 year
    noncurrent_version_transition_ia_days      = 30
    noncurrent_version_transition_glacier_days = 90
    noncurrent_version_expiration_days         = 365
    abort_incomplete_multipart_days            = 7

    # Allow the frontend origin to call the S3 pre-signed URL API directly
    cors_allowed_origins = ["*"]
    cors_allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    cors_allowed_headers = ["*"]
    cors_expose_headers  = ["ETag"]
    cors_max_age_seconds = 3600

    website_enabled = false
  }
}

# ── Database ──────────────────────────────────────────────────────────────────
rds_instance_class = "db.t4g.micro"
db_name            = "labhub"
db_username        = "labhub"
# db_password      → set via: export TF_VAR_db_password="..."

# ── Redis ─────────────────────────────────────────────────────────────────────
redis_node_type = "cache.t4g.micro"
# redis_auth_token → set via: export TF_VAR_redis_auth_token="..."

# ── Observability ─────────────────────────────────────────────────────────────
log_retention_days = 14

# ── Auto Stop/Start Scheduler ─────────────────────────────────────────────────
# ECS services, RDS and ElastiCache are stopped at 18:00 GMT+7 (11:00 UTC)
# and started again at 08:00 GMT+7 (01:00 UTC), Mon–Fri only.
# Controlled via enable_scheduler in the module flags block below.


# ── Module enable/disable flags ───────────────────────────────────────────────
# Set any flag to false to skip creating that module entirely.
# Useful for spinning up partial infrastructure (e.g. no DB yet, no DNS yet).
#
# Dependency rules (cross-module guards are enforced in main.tf):
#   enable_nginx     requires enable_ecs = true  (auto-disabled if enable_ecs = false)
#   enable_redis     SG ingress from ECS only when enable_ecs = true
#   enable_postgres  SG ingress from ECS only when enable_ecs = true
#   enable_scheduler requires enable_ecs + enable_postgres + enable_redis = true
#   enable_ecs_services uses enable_cloudwatch_logs + enable_secrets (gracefully optional)

enable_secrets         = true
enable_ecs             = true
enable_nginx           = true   # requires enable_ecs = true
enable_redis           = true
enable_postgres        = true
enable_s3              = true
enable_cloudwatch_logs = true
enable_route53         = false
enable_scheduler       = true   # requires enable_ecs + enable_postgres + enable_redis = true
enable_ecr             = true   # repos are auto-named from each service's name field in var.services above

