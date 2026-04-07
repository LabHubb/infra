variable "name_prefix" {
  type        = string
  description = "Prefix for all resource names"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs for the ALB"
}

variable "alb_sg_id" {
  type        = string
  description = "Security group ID for the ALB"
}

variable "acm_certificate_arn" {
  type        = string
  description = "ACM certificate ARN for HTTPS listener"
}

variable "enable_deletion_protection" {
  type        = bool
  default     = false
  description = "Enable deletion protection on the ALB"
}

variable "services" {
  type = map(object({
    name              = string
    container_port    = number
    cpu               = number
    memory            = number
    desired_count     = number
    path_pattern      = string
    priority          = number
    health_check_path = string
    image             = string
    public            = bool
  }))
  description = "Map of services to create target groups and listener rules for"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to all resources"
}
