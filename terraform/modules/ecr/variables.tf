variable "enable_ecr" {
  type        = bool
  description = "Set to false to skip creating all ECR repositories (count = 0). Useful when repos are pre-existing or managed elsewhere."
  default     = true
}

variable "project_name" {
  type        = string
  description = "Project name – used as the repository namespace prefix"
}

variable "environment" {
  type        = string
  description = "Environment name (dev, prod) – appended as suffix to ECR repo name"
}

variable "repositories" {
  type        = list(string)
  description = "List of service names to create ECR repositories for (e.g. [\"be\", \"fe-admin\", \"fe-customer\"])"
}

variable "image_tag_mutability" {
  type        = string
  description = "MUTABLE allows re-pushing the same tag (e.g. 'latest'). IMMUTABLE enforces unique tags (recommended for prod)."
  default     = "MUTABLE"
}

variable "scan_on_push" {
  type        = bool
  description = "Enable basic ECR image scanning on every push"
  default     = true
}

variable "untagged_expiry_days" {
  type        = number
  description = "Delete untagged images older than this many days (keeps the registry tidy)"
  default     = 7
}

variable "tagged_keep_count" {
  type        = number
  description = "How many tagged images to keep per repository (oldest pruned first)"
  default     = 10
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all ECR repositories"
  default     = {}
}
