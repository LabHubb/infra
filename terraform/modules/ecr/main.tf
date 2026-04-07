################################################################################
# ECR Module
# Creates one ECR repository per service with:
#   - Image scanning on push
#   - Lifecycle policy (prune old/untagged images)
#   - KMS encryption (AES-256 by default)
#
# Repositories are shared across environments (dev & prod push to the same repo).
# Typically provisioned ONCE via shared/bootstrap.
################################################################################

resource "aws_ecr_repository" "this" {
  for_each = var.enable_ecr ? toset(var.repositories) : toset([])

  name                 = "${var.project_name}/${each.value}"
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}/${each.value}"
  })
}

################################################################################
# Lifecycle policy – applied to every repository
# Rule 1: expire untagged images after N days
# Rule 2: keep only the latest N tagged images
################################################################################

resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Remove untagged images after ${var.untagged_expiry_days} days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.untagged_expiry_days
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep only the latest ${var.tagged_keep_count} tagged images"
        selection = {
          tagStatus   = "tagged"
          tagPrefixList = [""]
          countType   = "imageCountMoreThan"
          countNumber = var.tagged_keep_count
        }
        action = { type = "expire" }
      }
    ]
  })
}
