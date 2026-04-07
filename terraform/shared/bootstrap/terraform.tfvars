project_name = "myapp"
aws_region   = "ap-southeast-1"

# ── ECR Repositories ──────────────────────────────────────────────────────────
# One repository is created per entry, named: {project_name}/{service_name}
# e.g. myapp/be, myapp/fe-admin, myapp/fe-customer
#
# Add a new service name here whenever you add a new entry to var.services
# in any environment's terraform.tfvars.
ecr_repositories = ["be", "fe-admin", "fe-customer"]

# ── ECR enable/disable ────────────────────────────────────────────────────────
# Set to false if repositories already exist or are managed outside Terraform.
# When false, all aws_ecr_repository resources are skipped (for_each = []).
enable_ecr = true
