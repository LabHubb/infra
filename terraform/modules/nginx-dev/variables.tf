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
  description = "Public subnet IDs – EC2 nodes will be placed here and get public IPs"
}

variable "ami_id" {
  type        = string
  description = "ECS-optimized AMI (Amazon Linux 2) – nginx will be installed on top"
}

variable "instance_type" {
  type        = string
  default     = "t3a.medium"
  description = "EC2 instance type"
}

variable "ecs_cluster_name" {
  type        = string
  description = "ECS cluster name to register the instance into"
}

variable "ecs_sg_id" {
  type        = string
  description = "ECS security group ID – applied alongside the nginx SG so containers are reachable"
}

variable "ecs_instance_profile_name" {
  type        = string
  description = "IAM instance profile name from the ecs-cluster module"
}

variable "ssh_allowed_cidrs" {
  type        = list(string)
  default     = []
  description = "CIDRs allowed to SSH to the nginx EC2 instances (leave empty to disable)"
}

variable "services" {
  type = list(object({
    name           = string
    container_port = number
    path_pattern   = string
    nginx_hostname = string
  }))
  description = "List of services for nginx upstream + server block generation"
}

variable "asg_min_size" {
  type    = number
  default = 1
}

variable "asg_max_size" {
  type    = number
  default = 2
}

variable "asg_desired_capacity" {
  type    = number
  default = 1
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to all resources"
}
