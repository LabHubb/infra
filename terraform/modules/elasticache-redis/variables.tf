variable "name_prefix" {
  type        = string
  description = "Prefix for all resource names"
}

variable "redis_name" {
  type        = string
  description = "Short name for this Redis instance (appended to name_prefix)"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for the ElastiCache subnet group"
}

variable "redis_sg_id" {
  type        = string
  description = "Security group ID for the ElastiCache cluster"
}

variable "node_type" {
  type        = string
  default     = "cache.t4g.micro"
  description = "ElastiCache node type"
}

variable "engine_version" {
  type        = string
  default     = "7.1"
  description = "Redis engine version"
}

variable "num_cache_clusters" {
  type        = number
  default     = 1
  description = "Number of cache clusters (nodes). Use 2+ for Multi-AZ"
}

variable "auth_token" {
  type        = string
  sensitive   = true
  description = "Redis AUTH token (password)"
}

variable "snapshot_retention_limit" {
  type        = number
  default     = 1
  description = "Number of days to retain Redis snapshots"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to all resources"
}
