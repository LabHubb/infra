variable "name_prefix" {
  type        = string
  description = "Prefix for all resource names"
}

variable "sg_name" {
  type        = string
  description = "Short name for this security group (e.g. alb, ecs, redis, postgres)"
}

variable "description" {
  type        = string
  description = "Security group description"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "ingress_rules" {
  type = list(object({
    from_port    = number
    to_port      = number
    protocol     = string
    cidr_ipv4    = optional(string)
    source_sg_id = optional(string)
    description  = optional(string)
  }))
  default     = []
  description = "List of ingress rules"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to all resources"
}
