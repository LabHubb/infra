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
# IAM – tf-user deploy policy (managed here so it stays up-to-date)
# Run: cd shared/bootstrap && terraform apply
# to push the latest permissions to AWS whenever iam-deploy-policy.json changes.
################################################################################

data "aws_iam_user" "tf_user" {
  user_name = "tf-user"
}

resource "aws_iam_policy" "tf_deploy" {
  name        = "tf-user-policy"
  description = "Permissions for the tf-user Terraform deploy user – managed by bootstrap"
  policy      = file("${path.module}/iam-deploy-policy.json")

  tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
  }

  lifecycle {
    # Allow Terraform to update the policy in-place (creates a new version)
    create_before_destroy = true
  }
}

resource "aws_iam_user_policy_attachment" "tf_deploy" {
  user       = data.aws_iam_user.tf_user.user_name
  policy_arn = aws_iam_policy.tf_deploy.arn
}

################################################################################
# Outputs
################################################################################

output "state_bucket_name" {
  value = aws_s3_bucket.state.id
}

output "tf_deploy_policy_arn" {
  value       = aws_iam_policy.tf_deploy.arn
  description = "ARN of the tf-user deploy policy – update by running terraform apply in shared/bootstrap"
}



