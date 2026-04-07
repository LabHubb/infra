project_name = "labhub"
environment  = "dev"
aws_region   = "ap-southeast-1"

# ── Networking ────────────────────────────────────────────────────────────────
vpc_id             = "vpc-0123456789abcdef0"
vpc_cidr           = "10.0.0.0/16"
public_subnet_ids  = ["subnet-pub-a", "subnet-pub-b"]
private_subnet_ids = ["subnet-priv-a", "subnet-priv-b"]

# ── ECS / nginx EC2 nodes ─────────────────────────────────────────────────────
# Get latest ECS-optimized AMI:
# aws ssm get-parameter --name /aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id
ami_id               = "ami-0abcdef1234567890"
instance_type        = "t3a.medium"
asg_min_size         = 1
asg_max_size         = 2
asg_desired_capacity = 1

# Spot instances – saves ~70% vs on-demand in dev.
# spot_max_price = ""  means AWS caps the price at the current on-demand rate,
# so you are never charged more than on-demand, but you still benefit from the
# lower Spot market price. Set an explicit price (e.g. "0.05") to bid lower.
spot_max_price = ""

# SSH access to nginx EC2 (your office/home CIDR, or leave [] to disable)
ssh_allowed_cidrs = ["203.0.113.0/32"]

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
services = {
  be = {
    name              = "be-app"
    container_port    = 8080
    cpu               = 256
    memory            = 512
    desired_count     = 1
    path_pattern      = "/api/*"
    priority          = 10
    health_check_path = "/health"
    image_tag         = "latest"
    public            = false
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
  # }
}

# ── Storage ───────────────────────────────────────────────────────────────────
storage = {
  s3_bucket_name = "files"
  redis_name     = "redis"
  postgres_name  = "postgres"
}

# ── Database ──────────────────────────────────────────────────────────────────
rds_instance_class = "db.t4g.micro"
db_name            = "myapp"
db_username        = "myapp_admin"
# db_password      → set via: export TF_VAR_db_password="..."

# ── Redis ─────────────────────────────────────────────────────────────────────
redis_node_type = "cache.t4g.micro"
# redis_auth_token → set via: export TF_VAR_redis_auth_token="..."

# ── Observability ─────────────────────────────────────────────────────────────
log_retention_days = 14

# ── Auto Stop/Start Scheduler ─────────────────────────────────────────────────
# ECS services, RDS and ElastiCache are stopped at 18:00 GMT+7 (11:00 UTC)
# and started again at 08:00 GMT+7 (01:00 UTC), Mon–Fri only.
# Set to false to disable (e.g. during a sprint that runs overnight).
enable_scheduler = true


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
enable_route53         = true
enable_scheduler       = true   # requires enable_ecs + enable_postgres + enable_redis = true
enable_ecr             = true   # repos are auto-named from each service's name field in var.services above

