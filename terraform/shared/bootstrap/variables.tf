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


