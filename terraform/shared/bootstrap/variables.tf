variable "project_name" {
  type        = string
  description = "Project name – used to name the state bucket"
  default     = "myapp"
}

variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "ap-southeast-1"
}

variable "ecr_repositories" {
  type        = list(string)
  description = "Service names to create ECR repositories for. Matches the service keys in terraform.tfvars."
  default     = ["be", "fe-admin", "fe-customer"]
}

variable "enable_ecr" {
  type        = bool
  description = "Set to false to skip ECR repository creation (e.g. repos already exist or are managed elsewhere)."
  default     = true
}

