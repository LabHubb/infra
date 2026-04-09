################################################################################
# Provider
################################################################################

provider "aws" {
  region = var.aws_region
}

terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

################################################################################
# Current AWS account (needed to build IAM policy ARNs in scheduler module)
################################################################################

data "aws_caller_identity" "current" {}

################################################################################
# Auto-fetch latest ECS-optimized Amazon Linux 2 AMI (used when ami_id is null)
################################################################################

data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

################################################################################
# Locals
################################################################################

locals {
  # Use provided ami_id or fall back to the latest ECS-optimized AMI
  resolved_ami_id = var.ami_id != null ? var.ami_id : data.aws_ssm_parameter.ecs_ami.value

  name_prefix = "aws-sg-${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  # ECR base URL – auto-detected from the authenticated AWS account & region.
  # No account ID ever needs to be hardcoded in tfvars.
  ecr_base_url = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"

  # Auto-resolved infra environment variables injected into every ECS service.
  # These are resolved from module outputs so no hardcoding is needed in tfvars.
  infra_env_vars = concat(
    var.enable_secrets ? [
      { name = "AWS_SECRET_NAME", value = module.secrets[0].secret_name },
    ] : [],
    var.enable_postgres ? [
      { name = "DATABASE_HOST", value = module.postgres[0].db_address },
      { name = "DATABASE_PORT", value = tostring(module.postgres[0].db_port) },
      { name = "DATABASE_USER", value = var.db_username },
      { name = "DATABASE_NAME", value = var.db_name },
    ] : [],
    var.enable_redis ? [
      { name = "REDIS_HOST", value = module.redis[0].redis_endpoint },
      { name = "REDIS_PORT", value = tostring(module.redis[0].redis_port) },
    ] : [],
  )

  # Merge full image URL into each service definition using account ID + region
  # ECR repo name format: {project_name}-{service}-{environment}  e.g. labhub-be-dev
  services_with_image = {
    for k, v in var.services : k => merge(v, {
      image = "${local.ecr_base_url}/${var.project_name}-${v.name}-${var.environment}:${v.image_tag}"
      # Infra vars (DB, Redis) are prepended; user-defined vars in tfvars come after
      # and can override them if needed.
      environment_variables = concat(local.infra_env_vars, v.environment_variables)
    })
  }

  # ECR repository names derived automatically from service names.
  ecr_repository_names = [for k, v in var.services : v.name]
}

################################################################################
# ECR Repositories
# Shared across environments – provisioned here so the flag lives alongside
# all other enable_* flags in terraform.tfvars.
################################################################################

module "ecr" {
  count  = var.enable_ecr ? 1 : 0
  source = "../../modules/ecr"

  project_name         = var.project_name
  environment          = var.environment
  repositories         = local.ecr_repository_names
  image_tag_mutability = "MUTABLE"
  scan_on_push         = true
  untagged_expiry_days = 7
  tagged_keep_count    = 10
  tags                 = local.common_tags
}

################################################################################
# Secrets Manager
################################################################################

module "secrets" {
  count  = var.enable_secrets ? 1 : 0
  source = "../../modules/secrets-manager"

  project_name = var.project_name
  environment  = var.environment
  secret_name  = "app-secrets"
  description  = "All application secrets for ${local.name_prefix} - managed by Terraform"
  tags         = local.common_tags

  # All keys are stored as one JSON object in AWS Secrets Manager:
  #   labhub-dev/app-secrets = { "DB_PASSWORD": "...", "REDIS_AUTH_TOKEN": "..." }
  # Add a new secret here + declare its variable below + set TF_VAR_xxx in shell.
  secrets = {
    DB_PASSWORD = {
      value = var.db_password
    }
    REDIS_PASSWORD = {
      value = var.redis_password
    }
    JWT_SECRET = {
      value = var.jwt_secret
    }
  }
}

################################################################################
# Security Groups
################################################################################

# ECS SG – allow traffic from nginx EC2 on any container port + inter-container
module "sg_ecs" {
  count  = var.enable_ecs ? 1 : 0
  source = "../../modules/security-group"

  name_prefix = local.name_prefix
  sg_name     = "ecs"
  description = "ECS tasks - allow traffic from nginx on EC2 (same instance)"
  vpc_id      = var.vpc_id
  tags        = local.common_tags

  ingress_rules = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
      description = "HTTP from internet to nginx (host network)"
    },
    {
      from_port   = 0
      to_port     = 65535
      protocol    = "tcp"
      cidr_ipv4   = var.vpc_cidr
      description = "All TCP within VPC for inter-container communication"
    },
  ]
}

module "sg_redis" {
  count  = var.enable_redis ? 1 : 0
  source = "../../modules/security-group"

  name_prefix = local.name_prefix
  sg_name     = "redis"
  description = "Redis - allow access from ECS only"
  vpc_id      = var.vpc_id
  tags        = local.common_tags

  ingress_rules = var.enable_ecs ? [
    {
      from_port    = 6379
      to_port      = 6379
      protocol     = "tcp"
      source_sg_id = module.sg_ecs[0].sg_id
      description  = "Redis from ECS"
    },
  ] : []
}

module "sg_postgres" {
  count  = var.enable_postgres ? 1 : 0
  source = "../../modules/security-group"

  name_prefix = local.name_prefix
  sg_name     = "postgres"
  description = "Postgres - allow access from ECS only"
  vpc_id      = var.vpc_id
  tags        = local.common_tags

  ingress_rules = var.enable_ecs ? [
    {
      from_port    = 5432
      to_port      = 5432
      protocol     = "tcp"
      source_sg_id = module.sg_ecs[0].sg_id
      description  = "Postgres from ECS"
    },
  ] : []
}

################################################################################
# CloudWatch Log Groups
################################################################################

module "log_groups" {
  count  = var.enable_cloudwatch_logs ? 1 : 0
  source = "../../modules/cloudwatch-log-group"

  project_name      = var.project_name
  environment       = var.environment
  services          = { for k, v in local.services_with_image : k => { name = v.name } }
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

################################################################################
# ECS Cluster – EC2 nodes in PUBLIC subnets with public IPs (dev)
################################################################################

module "ecs_cluster" {
  count  = var.enable_ecs ? 1 : 0
  source = "../../modules/ecs-cluster"

  name_prefix                 = local.name_prefix
  ami_id                      = local.resolved_ami_id
  instance_type               = var.instance_type
  ecs_sg_id                   = module.sg_ecs[0].sg_id
  subnet_ids                  = var.public_subnet_ids # public subnets for dev
  associate_public_ip_address = true                  # public IP on each node
  asg_min_size                = var.asg_min_size
  asg_max_size                = var.asg_max_size
  asg_desired_capacity        = var.asg_desired_capacity
  use_spot                    = true               # Spot instances in dev to save cost
  spot_max_price              = var.spot_max_price # "" = on-demand price cap
  tags                        = local.common_tags
}

################################################################################
# Nginx ECS Service – reverse proxy running as a container on the ECS EC2 node
# Uses host network mode → binds to port 80 on the EC2 public IP directly.
# No separate EC2 instance or ALB needed in dev.
################################################################################

module "nginx" {
  count  = var.enable_nginx && var.enable_ecs ? 1 : 0
  source = "../../modules/nginx-dev"

  name_prefix            = local.name_prefix
  project_name           = var.project_name
  environment            = var.environment
  aws_region             = var.aws_region
  ecs_cluster_id         = module.ecs_cluster[0].cluster_id
  capacity_provider_name = module.ecs_cluster[0].capacity_provider_name
  log_retention_days     = var.log_retention_days
  tags                   = local.common_tags

  services = [
    for k, v in local.services_with_image : {
      name           = v.name
      container_port = v.container_port
      path_pattern   = v.path_pattern
      nginx_hostname = lookup(var.service_hostnames, k, "${v.name}.dev.example.com")
    }
  ]
}

################################################################################
# ECS Services (no ALB – nginx handles routing)
################################################################################

module "ecs_services" {
  source   = "../../modules/ecs-service"
  for_each = var.enable_ecs ? local.services_with_image : {}

  name_prefix            = local.name_prefix
  project_name           = var.project_name
  environment            = var.environment
  aws_region             = var.aws_region
  cluster_id             = module.ecs_cluster[0].cluster_id
  capacity_provider_name = module.ecs_cluster[0].capacity_provider_name
  target_group_arn       = "" # No ALB in dev
  log_group_name         = var.enable_cloudwatch_logs ? module.log_groups[0].log_group_names[each.key] : "/aws/ecs/${var.project_name}/${var.environment}/${each.value.name}"
  service                = each.value
  tags                   = local.common_tags

  # Inject all shared secrets into every service (execution role – container startup)
  secret_arns = var.enable_secrets ? module.secrets[0].secret_arns : {}

  # Task role – runtime access to AWS services
  s3_bucket_arns              = var.enable_s3 ? values(module.s3[0].bucket_arns) : []
  secrets_manager_secret_arns = var.enable_secrets ? [module.secrets[0].secret_arn] : []
  # RDS and Redis: password auth via Secrets Manager (no IAM auth policy needed)
}

################################################################################
# S3 Buckets
# Define any number of buckets in var.s3_buckets (terraform.tfvars).
# Setting enable_s3 = false skips all bucket provisioning.
################################################################################

module "s3" {
  count  = var.enable_s3 ? 1 : 0
  source = "../../modules/s3-bucket"

  name_prefix = local.name_prefix
  buckets     = var.s3_buckets
  tags        = local.common_tags
}

################################################################################
# ElastiCache Redis
################################################################################

module "redis" {
  count  = var.enable_redis ? 1 : 0
  source = "../../modules/elasticache-redis"

  name_prefix        = local.name_prefix
  redis_name         = var.storage.redis_name
  private_subnet_ids = var.private_subnet_ids
  redis_sg_id        = module.sg_redis[0].sg_id
  node_type          = var.redis_node_type
  auth_token         = var.redis_password
  tags               = local.common_tags
}

################################################################################
# RDS PostgreSQL
################################################################################

module "postgres" {
  count  = var.enable_postgres ? 1 : 0
  source = "../../modules/rds-postgres"

  name_prefix        = local.name_prefix
  postgres_name      = var.storage.postgres_name
  private_subnet_ids = var.private_subnet_ids
  postgres_sg_id     = module.sg_postgres[0].sg_id
  instance_class     = var.rds_instance_class
  db_name            = var.db_name
  db_username        = var.db_username
  db_password        = var.db_password
  tags               = local.common_tags
}

################################################################################
# Route53 – point directly to nginx ASG EC2 instances via fixed hostnames
# (In dev, each instance's public IP is ephemeral; consider an Elastic IP per
#  instance or use a wildcard *.dev.example.com CNAME if using a static host.)
################################################################################

module "route53" {
  count  = var.enable_route53 ? 1 : 0
  source = "../../modules/route53"

  hosted_zone_name = var.hosted_zone_name

  # Dev: no ALB – A records point directly to nginx EC2 public IPs.
  # Populate nginx_ec2_public_ips in terraform.tfvars with your Elastic IPs
  # (or run a second apply after noting the auto-assigned public IPs).
  alb_dns_name        = ""
  alb_zone_id         = ""
  ip_addresses        = var.nginx_ec2_public_ips
  service_dns_records = var.service_dns_map
  tags                = local.common_tags
}

################################################################################
# Auto Stop/Start Scheduler (dev only)
# Start: 08:00 GMT+7 (01:00 UTC)  Mon–Fri
# Stop:  18:00 GMT+7 (11:00 UTC)  Mon–Fri
################################################################################

module "scheduler" {
  count  = var.enable_scheduler && var.enable_ecs && var.enable_postgres && var.enable_redis ? 1 : 0
  source = "../../modules/scheduler"

  name_prefix    = local.name_prefix
  aws_region     = var.aws_region
  aws_account_id = data.aws_caller_identity.current.account_id
  tags           = local.common_tags

  # ECS
  ecs_cluster_name = module.ecs_cluster[0].cluster_name
  ecs_services = {
    for k, v in local.services_with_image : k => {
      service_name  = module.ecs_services[k].service_name
      desired_count = v.desired_count
    }
  }

  # ASG
  asg_name             = module.ecs_cluster[0].autoscaling_group_name
  asg_min_size         = var.asg_min_size
  asg_max_size         = var.asg_max_size
  asg_desired_capacity = var.asg_desired_capacity

  # RDS
  rds_identifier = module.postgres[0].db_identifier

  # ElastiCache
  redis_replication_group_id = module.redis[0].redis_replication_group_id
}

################################################################################
# Outputs
################################################################################

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = var.enable_ecs ? module.ecs_cluster[0].cluster_name : null
}

output "redis_endpoint" {
  description = "Redis primary endpoint"
  value       = var.enable_redis ? module.redis[0].redis_endpoint : null
}

output "postgres_endpoint" {
  description = "Postgres DB endpoint"
  value       = var.enable_postgres ? module.postgres[0].db_endpoint : null
}

output "s3_bucket_names" {
  description = "Map of S3 bucket key → bucket name"
  value       = var.enable_s3 ? module.s3[0].bucket_names : {}
}

output "s3_bucket_arns" {
  description = "Map of S3 bucket key → bucket ARN"
  value       = var.enable_s3 ? module.s3[0].bucket_arns : {}
}

output "ecs_service_names" {
  description = "Map of ECS service names"
  value       = { for k, v in module.ecs_services : k => v.service_name }
}

output "secret_arn" {
  description = "ARN of the single combined Secrets Manager secret (labhub-dev/app-secrets)"
  value       = var.enable_secrets ? module.secrets[0].secret_arn : null
}

output "secret_arns" {
  description = "Map of key → ARN::KEY suffix for ECS task definition injection"
  value       = var.enable_secrets ? module.secrets[0].secret_arns : null
  sensitive   = true
}

output "ecr_repository_urls" {
  description = "ECR repository URLs – empty map when enable_ecr = false"
  value       = var.enable_ecr ? module.ecr[0].repository_urls : {}
}

