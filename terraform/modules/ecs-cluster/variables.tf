variable "name_prefix" {
  type        = string
  description = "Prefix for all resource names"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to all resources"
}

variable "ami_id" {
  type        = string
  description = "ECS-optimized AMI ID for EC2 instances"
}

variable "instance_type" {
  type        = string
  default     = "t3a.medium"
  description = "EC2 instance type for ECS cluster nodes"
}

variable "ecs_sg_id" {
  type        = string
  description = "Security group ID for ECS EC2 instances"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for the ASG (use public subnets for dev, private for prod)"
}

variable "associate_public_ip_address" {
  type        = bool
  default     = false
  description = "Whether EC2 instances get a public IP (true for dev, false for prod)"
}

variable "asg_min_size" {
  type        = number
  default     = 1
  description = "Minimum number of EC2 instances in ASG"
}

variable "asg_max_size" {
  type        = number
  default     = 5
  description = "Maximum number of EC2 instances in ASG"
}

variable "asg_desired_capacity" {
  type        = number
  default     = 2
  description = "Desired number of EC2 instances in ASG"
}

variable "use_spot" {
  type        = bool
  default     = false
  description = "Use Spot instances for ECS EC2 nodes (recommended for dev to save cost)"
}

variable "spot_max_price" {
  type        = string
  default     = ""
  description = "Maximum Spot price per hour (e.g. '0.05'). Empty string means the on-demand price cap."
}

