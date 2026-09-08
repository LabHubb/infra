project_name = "labhub"
environment  = "dev"
aws_region   = "ap-southeast-1"

# ── Networking ────────────────────────────────────────────────────────────────
vpc_id   = "vpc-0edcb9983676899a7"
vpc_cidr = "172.31.0.0/16"
# All 3 AZs are listed so the Spot ASG can fall back when one AZ runs dry.
# Pinning to a single AZ caused an outage: with one instance type in one AZ the
# ASG had exactly one Spot pool and failed with UnfulfillableCapacity.
# Dev has no EIP and uses path-based nginx routing, so the node's AZ is free to vary.
public_subnet_ids = [
  "subnet-004654dc97acf9435", # ap-southeast-1a
  "subnet-06fd6a05ad6f7df9c", # ap-southeast-1b
  "subnet-0b3e97b06cb555a92", # ap-southeast-1c
]
# RDS and ElastiCache require at least 2 subnets in different AZs for their subnet groups.
# We still deploy the DB instances in 1 AZ but the subnet group must span 2 AZs.
private_subnet_ids = ["subnet-004654dc97acf9435", "subnet-06fd6a05ad6f7df9c"]

# ── ECS / nginx EC2 nodes ─────────────────────────────────────────────────────
# ami_id: pin to a pre-baked custom AMI so packages (htop, git, jq, psql, etc.)
# are NOT installed on every instance boot.
#
# HOW TO BAKE YOUR AMI (run once):
#   1. Find base:  aws ssm get-parameter --name /aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id --region ap-southeast-1 --query Parameter.Value --output text
#   2. Launch EC2: aws ec2 run-instances --image-id <BASE_AMI> --instance-type t3a.small --region ap-southeast-1 ...
#   3. SSM in:     aws ssm start-session --target <INSTANCE_ID> --region ap-southeast-1
#   4. Install:    sudo dnf update -y && sudo dnf install -y htop git curl jq postgresql16
#   5. Bake:       aws ec2 create-image --instance-id <INSTANCE_ID> --name "labhub-ecs-al2023-$(date +%Y%m%d)" --no-reboot --region ap-southeast-1
#   6. Terminate:  aws ec2 terminate-instances --instance-ids <INSTANCE_ID>
#   7. Paste the new AMI ID below and run terraform apply.
#
# Set to null to auto-fetch latest ECS-optimized AL2023 from SSM (no pre-installs).
ami_id               = "ami-0518e487803f0c4ce" # baked 20260529-v2 - htop git jq psql16 redis-cli(6.2.20) cloudwatch-agent
instance_type        = "t3a.small"             # 1 vCPU, 2GB RAM, AMD
asg_min_size         = 1
asg_max_size         = 1
asg_desired_capacity = 1

# Spot instances – saves ~70% vs on-demand in dev.
# spot_max_price = ""  means AWS caps the price at the current on-demand rate,
# so you are never charged more than on-demand, but you still benefit from the
# lower Spot market price. Set an explicit price (e.g. "0.05") to bid lower.
spot_max_price = ""

# Extra Spot pools. Combined with the 3 AZs above this gives the ASG 12 pools
# (4 types x 3 AZs) instead of 1, so a single drained pool no longer blocks launches.
# capacity-optimized allocation picks whichever pool is deepest, not the cheapest.
# ALL types must stay x86_64 to match ami_id – t4g.* is ARM and will NOT boot.
spot_instance_types = ["t3.small", "t3a.medium", "t3.medium"]

# 0 = fully Spot. Set to 1 to guarantee an On-Demand node always launches
# (removes the ~70% Spot saving; use only if Spot outages keep blocking dev).
on_demand_base_capacity = 0

# SSH is handled via AWS Systems Manager (SSM) Session Manager.
# No port 22 or SSH key needed. Connect via: AWS Console > SSM > Session Manager

# ── DNS ───────────────────────────────────────────────────────────────────────
# Route53 is DISABLED in dev (enable_route53 = false).
# Nginx uses path-based routing – no hostname/DNS required.
# Access services directly via EC2 public IP:
#   http://<EC2-public-IP>/api/...        -> be-app
#   http://<EC2-public-IP>/admin/api/...  -> be-admin
#   http://<EC2-public-IP>/admin/...      -> fe-admin  (when enabled)
#   http://<EC2-public-IP>/...            -> fe-customer (when enabled)
# nginx matches the longest path prefix regardless of listing order, so
# /admin/api/* always wins over fe-admin's /admin/* for admin API calls.

# ── ECS Services ──────────────────────────────────────────────────────────────
# Only specify image_tag (e.g. "latest", "v1.2.3").
# The full ECR URL is auto-constructed in main.tf using your AWS account ID + region.
#
# The following environment variables are automatically injected into ALL services
# from module outputs – do NOT add them manually here:
#   DATABASE_HOST, DATABASE_PORT, DATABASE_USER, DATABASE_NAME  → from RDS module
#   REDIS_HOST, REDIS_PORT                                       → from redis_container module (172.17.0.1:6379)
services = {
  be-app = {
    name                  = "be-app"
    container_port        = 8080 # also used as host port; must be unique per service
    cpu                   = 256
    memory                = 512
    desired_count         = 1
    path_pattern          = "/api/*"
    priority              = 10
    health_check_path     = "/api/v1/health" # ALB health check endpoint
    health_check_matcher  = "200"            # only HTTP 200 is considered healthy
    health_check_interval = 30               # seconds between checks
    image_tag             = "latest"
    public                = false

    environment_variables = [
      # Application Configuration
      { name = "APP_NAME", value = "Medical Booking API" },
      { name = "APP_ENV", value = "development" },
      { name = "APP_PORT", value = "8080" },
      { name = "APP_DEBUG", value = "true" },
      { name = "APP_TIMEZONE", value = "Asia/Ho_Chi_Minh" },

      # Database Configuration
      { name = "DATABASE_SSLMODE", value = "require" },
      { name = "DATABASE_MAX_IDLE_CONNS", value = "10" },
      { name = "DATABASE_MAX_OPEN_CONNS", value = "100" },
      { name = "DATABASE_CONN_MAX_LIFETIME", value = "1h" },

      # Matching Configuration
      { name = "MATCHING_ENABLED", value = "true" },
      { name = "MATCHING_OFFER_TIMEOUT_SEC", value = "60" },
      { name = "MATCHING_MAX_OFFERS_PER_ORDER", value = "5" },
      { name = "MATCHING_RADIUS_STEPS_KM", value = "2,4,8,16" },
      { name = "MATCHING_DUE_POLL_INTERVAL_SEC", value = "2" },
      { name = "MATCHING_SESSION_TTL_HOURS", value = "24" },

      # Firebase Cloud Messaging
      { name = "FCM_ENABLED", value = "false" },
      { name = "FCM_PROJECT_ID", value = "" },
      { name = "FCM_ACCESS_TOKEN", value = "" },
      { name = "FCM_PRIVATE_KEY", value = "" },
      { name = "FCM_CLIENT_EMAIL", value = "" },

      # Redis Configuration
      # REDIS_HOST, REDIS_PORT and REDIS_PASSWORD are auto-injected from infra_env_vars.
      # Set TF_VAR_redis_password in your shell before running terraform apply.
      { name = "REDIS_DB", value = "0" },
      { name = "REDIS_MAX_RETRIES", value = "3" },
      { name = "REDIS_POOL_SIZE", value = "10" },
      { name = "REDIS_MIN_IDLE_CONNS", value = "5" },

      # JWT Configuration
      { name = "JWT_ACCESS_TOKEN_EXPIRE_MINUTES", value = "1440" },
      { name = "JWT_REFRESH_TOKEN_EXPIRE_DAYS", value = "30" },
      { name = "JWT_ISSUER", value = "medical-booking-system" },
      { name = "JWT_AUDIENCE", value = "medical-booking-users" },

      # OTP Configuration
      { name = "OTP_CODE_LENGTH", value = "6" },
      { name = "OTP_CODE_TYPE", value = "numeric" },
      { name = "OTP_TTL_MINUTES", value = "5" },
      { name = "OTP_MAX_ATTEMPTS_PER_OTP", value = "5" },
      { name = "OTP_MAX_DAILY_ATTEMPTS", value = "10" },
      { name = "OTP_DAILY_BLOCK_HOURS", value = "24" },
      { name = "OTP_COOLDOWN_SECONDS", value = "300" },
      { name = "OTP_FIXED_CODE", value = "111999" },

      # Security Configuration
      { name = "SECURITY_RATE_LIMIT_LOGIN_ATTEMPTS", value = "5" },
      { name = "SECURITY_RATE_LIMIT_LOGIN_WINDOW_MINUTES", value = "15" },
      { name = "SECURITY_RATE_LIMIT_OTP_ATTEMPTS", value = "3" },
      { name = "SECURITY_RATE_LIMIT_OTP_WINDOW_MINUTES", value = "5" },
      { name = "SECURITY_MAX_FAILED_LOGIN_ATTEMPTS", value = "5" },
      { name = "SECURITY_ACCOUNT_LOCKOUT_DURATION_MINUTES", value = "30" },
      { name = "SECURITY_OTP_EXPIRY_MINUTES", value = "5" },
      { name = "SECURITY_EMAIL_VERIFICATION_EXPIRE_HOURS", value = "24" },
      { name = "SECURITY_PHONE_VERIFICATION_EXPIRE_MINUTES", value = "5" },
      { name = "SECURITY_PASSWORD_RESET_EXPIRE_HOURS", value = "1" },

      # Password Policy
      { name = "PASSWORD_MIN_LENGTH", value = "8" },
      { name = "PASSWORD_REQUIRE_UPPERCASE", value = "true" },
      { name = "PASSWORD_REQUIRE_LOWERCASE", value = "true" },
      { name = "PASSWORD_REQUIRE_NUMBERS", value = "true" },
      { name = "PASSWORD_REQUIRE_SPECIAL_CHARS", value = "false" },
      { name = "PASSWORD_BCRYPT_COST", value = "12" },

      # Email Configuration
      { name = "EMAIL_ENABLED", value = "false" },
      { name = "EMAIL_SMTP_HOST", value = "smtp.gmail.com" },
      { name = "EMAIL_SMTP_PORT", value = "587" },
      { name = "EMAIL_SMTP_USERNAME", value = "" },
      { name = "EMAIL_SMTP_PASSWORD", value = "" },
      { name = "EMAIL_FROM_EMAIL", value = "noreply@medicalbooking.com" },
      { name = "EMAIL_FROM_NAME", value = "Medical Booking System" },
      { name = "EMAIL_USE_TLS", value = "true" },

      # SMS Configuration
      { name = "SMS_ENABLED", value = "false" },
      { name = "SMS_PROVIDER", value = "mock" },
      { name = "SMS_API_KEY", value = "" },
      { name = "SMS_API_SECRET", value = "" },
      { name = "SMS_FROM_NUMBER", value = "" },

      # Upload Configuration
      { name = "UPLOAD_MAX_SIZE_MB", value = "10" },
      { name = "UPLOAD_DIR", value = "./uploads" },
      { name = "UPLOAD_STORAGE_TYPE", value = "s3" },

      # Logging Configuration
      { name = "LOG_LEVEL", value = "debug" },
      { name = "LOG_FORMAT", value = "json" },
      { name = "LOG_OUTPUT", value = "stdout" },
    ]
  }

  be-admin = {
    name                  = "be-admin"
    # Must differ from be-app's 8080 – dev runs a single EC2 node, so bridge-mode
    # hostPort collisions across services on the same instance would fail to start.
    container_port        = 8081
    cpu                   = 256
    memory                = 512
    desired_count         = 1
    path_pattern          = "/admin/api/*"
    priority              = 15 # between be-app (10) and fe-admin (20)
    # nginx rewrites the public /admin/api/* down to /api/* before proxying, since
    # be-app already owns /api on this host and both services expose /auth/login.
    #   GET /admin/api/v1/labs  ->  127.0.0.1:8081/api/v1/labs
    upstream_path         = "/api"
    # Probes hit the container port directly, bypassing nginx, so this must be the
    # path the app itself serves (APP_BASE_PATH below), not the public prefix.
    health_check_path     = "/api/v1/health"
    health_check_matcher  = "200"
    health_check_interval = 30
    image_tag             = "latest"
    public                = false

    environment_variables = [
      { name = "APP_NAME", value = "LabHub Admin API" },
      { name = "APP_ENV", value = "development" },
      # APP_PORT must match container_port above.
      # APP_BASE_PATH stays at the app's own default: be-admin serves /api/v1, and
      # nginx strips the public /admin prefix on the way in (see upstream_path).
      { name = "APP_PORT", value = "8081" },
      { name = "APP_BASE_PATH", value = "/api/v1" },
      { name = "APP_DEBUG", value = "true" },
      { name = "APP_TIMEZONE", value = "Asia/Ho_Chi_Minh" },

      # Database Configuration
      { name = "DATABASE_SSLMODE", value = "require" },
      { name = "DATABASE_MAX_IDLE_CONNS", value = "10" },
      { name = "DATABASE_MAX_OPEN_CONNS", value = "100" },
      { name = "DATABASE_CONN_MAX_LIFETIME", value = "1h" },

      # Redis Configuration – separate logical DB from be-app (DB 0) so admin
      # sessions/login-lockout counters never collide with app-side keys.
      { name = "REDIS_DB", value = "1" },
      { name = "REDIS_MAX_RETRIES", value = "3" },
      { name = "REDIS_POOL_SIZE", value = "10" },
      { name = "REDIS_MIN_IDLE_CONNS", value = "5" },

      # JWT Configuration
      { name = "JWT_ACCESS_TOKEN_EXPIRE_MINUTES", value = "30" },
      { name = "JWT_REFRESH_TOKEN_EXPIRE_DAYS", value = "7" },
      { name = "JWT_ISSUER", value = "labhub-admin" },
      { name = "JWT_AUDIENCE", value = "labhub-webadmin" },

      # Security Configuration (BRS sheet "2" epic 1)
      { name = "SECURITY_CAPTCHA_AFTER_ATTEMPTS", value = "3" },
      { name = "SECURITY_MAX_FAILED_LOGIN_ATTEMPTS", value = "5" },
      { name = "SECURITY_ACCOUNT_LOCKOUT_DURATION_MINUTES", value = "15" },
      { name = "SECURITY_LOGIN_FAILURE_WINDOW_MINUTES", value = "15" },
      { name = "SECURITY_SESSION_TIMEOUT_MINUTES", value = "30" },
      { name = "SECURITY_PASSWORD_RESET_EXPIRE_MINUTES", value = "15" },
      { name = "SECURITY_PROFILE_SLA_DAYS", value = "2" },

      # Password Policy
      { name = "PASSWORD_MIN_LENGTH", value = "8" },
      { name = "PASSWORD_REQUIRE_NUMBERS", value = "true" },
      { name = "PASSWORD_REQUIRE_SPECIAL_CHARS", value = "true" },
      { name = "PASSWORD_BCRYPT_COST", value = "12" },

      # CORS – webadmin dev origin; adjust once fe-admin is deployed to this env.
      { name = "CORS_ALLOWED_ORIGINS", value = "http://localhost:5173" },

      # Logging Configuration
      { name = "LOG_LEVEL", value = "debug" },
      { name = "LOG_FORMAT", value = "json" },
      { name = "LOG_OUTPUT", value = "stdout" },
    ]
  }
  #
  # fe_admin = {
  #   name              = "fe-admin"
  #   container_port    = 3001   # must be unique per service (nginx upstream uses this as host port)
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
  #   container_port    = 3002   # must be unique per service (nginx upstream uses this as host port)
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
# Dev: Redis runs as an ECS container (redis:7-alpine) instead of ElastiCache.
# The container starts with --requirepass using var.redis_password.
# REDIS_HOST (172.17.0.1), REDIS_PORT (6379) and REDIS_PASSWORD are all
# auto-injected into every app container via infra_env_vars.
#
# redis_node_type is unused when enable_redis = false.
# redis_node_type = "cache.t4g.micro"
#
# redis_password → set via: export TF_VAR_redis_password="your-dev-password"
# jwt_secret     → set via: export TF_VAR_jwt_secret="..."
# payment_client_id    → set via: export TF_VAR_payment_client_id="..."
# payment_api_key      → set via: export TF_VAR_payment_api_key="..."
# payment_checksum_key → set via: export TF_VAR_payment_checksum_key="..."
# fcm_project_id       → set via: export TF_VAR_fcm_project_id="..."
# fcm_private_key      → set via: export TF_VAR_fcm_private_key="..."
# fcm_client_email     → set via: export TF_VAR_fcm_client_email="..."

# ── Observability ─────────────────────────────────────────────────────────────
log_retention_days = 14

# ── Auto Stop/Start Scheduler ─────────────────────────────────────────────────
# ECS services (including Redis container), RDS and ASG are stopped at 18:00 GMT+7
# (11:00 UTC) and started again at 08:00 GMT+7 (01:00 UTC), Mon–Fri only.
# Redis-as-container stops/starts automatically with the ECS ASG.
# Controlled via enable_scheduler in the module flags block below.


# ── Module enable/disable flags ───────────────────────────────────────────────
# Set any flag to false to skip creating that module entirely.
# Useful for spinning up partial infrastructure (e.g. no DB yet, no DNS yet).
#
# Dependency rules (cross-module guards are enforced in main.tf):
#   enable_nginx     requires enable_ecs = true  (auto-disabled if enable_ecs = false)
#   enable_redis     SG ingress from ECS only when enable_ecs = true  (ElastiCache)
#   enable_postgres  SG ingress from ECS only when enable_ecs = true
#   enable_scheduler requires enable_ecs + enable_postgres = true
#                    (Redis-as-container is stopped automatically with ECS)
#   enable_ecs_services uses enable_cloudwatch_logs + enable_secrets (gracefully optional)

enable_secrets         = true # KEEP – not destroyed
enable_ecs             = true
enable_nginx           = true
enable_redis           = false # ElastiCache disabled – use enable_redis_container instead
enable_redis_container = true  # Redis runs as a standalone ECS service (redis:7-alpine)
enable_postgres        = true
enable_s3              = true # KEEP – not destroyed
enable_cloudwatch_logs = true
enable_route53         = false
enable_scheduler       = true
enable_ecr             = true

