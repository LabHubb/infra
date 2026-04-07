################################################################################
# Bootstrap: Terraform Remote State Bucket + DynamoDB Lock Table
# Apply this ONCE before any environment. Not managed by remote state itself.
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

resource "aws_s3_bucket" "state" {
  bucket = "${var.project_name}-terraform-state"

  tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
    Purpose   = "Terraform remote state"
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

################################################################################
# ECR Repositories (shared across dev + prod – provisioned once here)
################################################################################

module "ecr" {
  source       = "../../modules/ecr"
  project_name = var.project_name
  repositories = var.ecr_repositories
  enable_ecr   = var.enable_ecr

  image_tag_mutability = "MUTABLE"   # allow re-pushing :latest
  scan_on_push         = true
  untagged_expiry_days = 7
  tagged_keep_count    = 10

  tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}

################################################################################
# Outputs
################################################################################

output "state_bucket_name" {
  value = aws_s3_bucket.state.id
}

output "ecr_repository_urls" {
  description = "Paste these URLs into each environment's terraform.tfvars as the 'image' values"
  value       = module.ecr.repository_urls
}

output "ecr_repository_arns" {
  description = "ECR repository ARNs – used in IAM policies for ECS task roles"
  value       = module.ecr.repository_arns
}


