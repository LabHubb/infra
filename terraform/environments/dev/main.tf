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
# Locals
################################################################################

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  # ECR base URL – auto-detected from the authenticated AWS account & region.
  # No account ID ever needs to be hardcoded in tfvars.
  ecr_base_url = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"

  # Merge full image URL into each service definition using account ID + region
  services_with_image = {
    for k, v in var.services : k => merge(v, {
      image = "${local.ecr_base_url}/${var.project_name}/${v.name}:${v.image_tag}"
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
  repositories         = local.ecr_repository_names
  image_tag_mutability = "MUTABLE" # allow re-pushing :latest in dev
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
  tags        = local.common_tags

  secrets = {
    db_password = {
      value       = var.db_password
      description = "PostgreSQL master password"
    }
    redis_password = {
      value       = var.redis_auth_token
      description = "Redis AUTH token"
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
  description = "ECS tasks – allow traffic from nginx on EC2 (same instance)"
  vpc_id      = var.vpc_id
  tags        = local.common_tags

  ingress_rules = [
    {
      from_port   = 0
      to_port     = 65535
      protocol    = "tcp"
      cidr_ipv4   = var.vpc_cidr
      description = "All TCP within VPC (nginx on same host proxies to containers)"
    },
  ]
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
# ECS Cluster – EC2 nodes in PUBLIC subnets with public IPs (dev)
################################################################################

module "ecs_cluster" {
  count  = var.enable_ecs ? 1 : 0
  source = "../../modules/ecs-cluster"

  name_prefix                 = local.name_prefix
  ami_id                      = var.ami_id
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
# Nginx on EC2 – reverse proxy / load balancer (replaces ALB in dev)
# Runs on the same EC2 instances as ECS via user_data
################################################################################

module "nginx" {
  count  = var.enable_nginx && var.enable_ecs ? 1 : 0
  source = "../../modules/nginx-dev"

  name_prefix = local.name_prefix
  vpc_id      = var.vpc_id

  public_subnet_ids         = var.public_subnet_ids
  ami_id                    = var.ami_id
  instance_type             = var.instance_type
  ecs_cluster_name          = module.ecs_cluster[0].cluster_name
  ecs_sg_id                 = module.sg_ecs[0].sg_id
  ecs_instance_profile_name = module.ecs_cluster[0].instance_profile_name
  ssh_allowed_cidrs         = var.ssh_allowed_cidrs
  asg_min_size              = var.asg_min_size
  asg_max_size              = var.asg_max_size
  asg_desired_capacity      = var.asg_desired_capacity
  tags                      = local.common_tags

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
  aws_region             = var.aws_region
  cluster_id             = module.ecs_cluster[0].cluster_id
  capacity_provider_name = module.ecs_cluster[0].capacity_provider_name
  target_group_arn       = "" # No ALB in dev
  log_group_name         = var.enable_cloudwatch_logs ? module.log_groups[0].log_group_names[each.key] : "/aws/ecs/${var.project_name}/${var.environment}/${each.value.name}"
  service                = each.value
  tags                   = local.common_tags

  # Inject all shared secrets into every service
  secret_arns = var.enable_secrets ? module.secrets[0].secret_arns : {}
}

################################################################################
# S3 Bucket
################################################################################

module "s3" {
  count  = var.enable_s3 ? 1 : 0
  source = "../../modules/s3-bucket"

  name_prefix   = local.name_prefix
  bucket_suffix = var.storage.s3_bucket_name
  tags          = local.common_tags
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

output "s3_bucket_name" {
  description = "S3 file storage bucket name"
  value       = var.enable_s3 ? module.s3[0].bucket_name : null
}

output "ecs_service_names" {
  description = "Map of ECS service names"
  value       = { for k, v in module.ecs_services : k => v.service_name }
}

output "secret_arns" {
  description = "Secrets Manager ARNs"
  value       = var.enable_secrets ? module.secrets[0].secret_arns : null
  sensitive   = true
}

output "ecr_repository_urls" {
  description = "ECR repository URLs – empty map when enable_ecr = false"
  value       = var.enable_ecr ? module.ecr[0].repository_urls : {}
}

