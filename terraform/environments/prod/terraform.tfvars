project_name = "myapp"
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
ami_id               = "ami-0abcdef1234567890"
instance_type        = "t3a.medium"
asg_min_size         = 2
asg_max_size         = 10
asg_desired_capacity = 3

# ── ALB / TLS ─────────────────────────────────────────────────────────────────
acm_certificate_arn            = "arn:aws:acm:ap-southeast-1:YOUR_ACCOUNT_ID:certificate/prod-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
enable_alb_deletion_protection = true

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
services = {
  be = {
    name              = "be"
    container_port    = 8080
    cpu               = 1024
    memory            = 2048
    desired_count     = 2
    path_pattern      = "/api/*"
    priority          = 10
    health_check_path = "/health"
    image_tag         = "latest"
    public            = false
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
  # }
}

# ── Storage ───────────────────────────────────────────────────────────────────
storage = {
  s3_bucket_name = "files"
  redis_name     = "redis"
  postgres_name  = "postgres"
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

