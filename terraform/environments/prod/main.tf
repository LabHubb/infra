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
# Current AWS account
################################################################################

data "aws_caller_identity" "current" {}

################################################################################
# Locals
################################################################################

locals {
  name_prefix = "aws-sg-${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  # ECR base URL – auto-detected from the authenticated AWS account & region.
  # No account ID ever needs to be hardcoded in tfvars.
  ecr_base_url = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"

  # Merge full image URL into each service definition using account ID + region
  # ECR repo name format: {project_name}-{service}-{environment}  e.g. labhub-be-prod
  services_with_image = {
    for k, v in var.services : k => merge(v, {
      image                 = "${local.ecr_base_url}/${var.project_name}-${v.name}-${var.environment}:${v.image_tag}"
      environment_variables = v.environment_variables
    })
  }

  # ECR repository names derived automatically from service names – no manual list needed.
  # Adding a new service to var.services will automatically create its ECR repo.
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
  image_tag_mutability = "IMMUTABLE" # enforce unique tags in prod
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

  name_prefix = local.name_prefix
  secret_name = "app-secrets"
  description = "All application secrets for ${local.name_prefix} – managed by Terraform"
  tags        = local.common_tags

  # All keys are stored as one JSON object in AWS Secrets Manager:
  #   labhub-prod/app-secrets = { "DB_PASSWORD": "...", "REDIS_AUTH_TOKEN": "..." }
  # Add a new secret here + declare its variable below + set TF_VAR_xxx in shell.
  secrets = {
    DB_PASSWORD = {
      value = var.db_password
    }
    REDIS_AUTH_TOKEN = {
      value = var.redis_auth_token
    }
  }
}

################################################################################
# Security Groups
################################################################################

module "sg_alb" {
  count  = var.enable_alb ? 1 : 0
  source = "../../modules/security-group"

  name_prefix = local.name_prefix
  sg_name     = "alb"
  description = "ALB – allow HTTP/HTTPS from the internet"
  vpc_id      = var.vpc_id
  tags        = local.common_tags

  ingress_rules = [
    { from_port = 80, to_port = 80, protocol = "tcp", cidr_ipv4 = "0.0.0.0/0", description = "HTTP" },
    { from_port = 443, to_port = 443, protocol = "tcp", cidr_ipv4 = "0.0.0.0/0", description = "HTTPS" },
  ]
}

module "sg_ecs" {
  count  = var.enable_ecs ? 1 : 0
  source = "../../modules/security-group"

  name_prefix = local.name_prefix
  sg_name     = "ecs"
  description = "ECS tasks – allow traffic from ALB only"
  vpc_id      = var.vpc_id
  tags        = local.common_tags

  ingress_rules = var.enable_alb ? [
    {
      from_port    = 0
      to_port      = 65535
      protocol     = "tcp"
      source_sg_id = module.sg_alb[0].sg_id
      description  = "All TCP from ALB"
    },
  ] : []
}

module "sg_redis" {
  count  = var.enable_redis ? 1 : 0
  source = "../../modules/security-group"

  name_prefix = local.name_prefix
  sg_name     = "redis"
  description = "Redis – allow access from ECS only"
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
  description = "Postgres – allow access from ECS only"
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
# ECS Cluster – EC2 nodes in PRIVATE subnets (prod)
#
# Billing: On-Demand instances (use_spot = false). Purchase a Compute Savings
# Plan in the AWS Billing console to get up to 66% discount automatically
# applied to these on-demand charges – no instance-type lock-in required.
# Recommended commitment: 1-year, no-upfront Compute Savings Plan covering
# the steady-state baseline (asg_min_size * instance on-demand hourly rate).
################################################################################

module "ecs_cluster" {
  count  = var.enable_ecs ? 1 : 0
  source = "../../modules/ecs-cluster"

  name_prefix                 = local.name_prefix
  ami_id                      = var.ami_id
  instance_type               = var.instance_type
  ecs_sg_id                   = module.sg_ecs[0].sg_id
  subnet_ids                  = var.private_subnet_ids # private subnets in prod
  associate_public_ip_address = false
  asg_min_size                = var.asg_min_size
  asg_max_size                = var.asg_max_size
  asg_desired_capacity        = var.asg_desired_capacity
  use_spot                    = false # On-Demand – covered by Compute Savings Plan
  tags                        = local.common_tags
}

################################################################################
# ALB (prod only)
################################################################################

module "alb" {
  count  = var.enable_alb ? 1 : 0
  source = "../../modules/alb"

  name_prefix                = local.name_prefix
  vpc_id                     = var.vpc_id
  public_subnet_ids          = var.public_subnet_ids
  alb_sg_id                  = module.sg_alb[0].sg_id
  acm_certificate_arn        = var.acm_certificate_arn
  enable_deletion_protection = var.enable_alb_deletion_protection
  services                   = local.services_with_image
  tags                       = local.common_tags
}

################################################################################
# ECS Services – ALB target group attached
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
  target_group_arn       = var.enable_alb ? module.alb[0].target_group_arns[each.key] : ""
  log_group_name         = var.enable_cloudwatch_logs ? module.log_groups[0].log_group_names[each.key] : "/aws/ecs/${var.project_name}/${var.environment}/${each.value.name}"
  service                = each.value
  tags                   = local.common_tags

  # Inject secrets from Secrets Manager into every container
  secret_arns = var.enable_secrets ? module.secrets[0].secret_arns : {}
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
  auth_token         = var.redis_auth_token
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
# Route53 – alias records → ALB
################################################################################

module "route53" {
  count  = var.enable_route53 ? 1 : 0
  source = "../../modules/route53"

  hosted_zone_name    = var.hosted_zone_name
  alb_dns_name        = var.enable_alb ? module.alb[0].alb_dns_name : ""
  alb_zone_id         = var.enable_alb ? module.alb[0].alb_zone_id : ""
  service_dns_records = var.service_dns_map
  tags                = local.common_tags
}

################################################################################
# Outputs
################################################################################

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = var.enable_alb ? module.alb[0].alb_dns_name : null
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

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = var.enable_ecs ? module.ecs_cluster[0].cluster_name : null
}

output "ecs_service_names" {
  description = "Map of ECS service names"
  value       = { for k, v in module.ecs_services : k => v.service_name }
}

output "dns_records" {
  description = "Route53 DNS FQDNs for each service"
  value       = var.enable_route53 ? module.route53[0].record_fqdns : null
}

output "secret_arn" {
  description = "ARN of the single combined Secrets Manager secret (labhub-prod/app-secrets)"
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

