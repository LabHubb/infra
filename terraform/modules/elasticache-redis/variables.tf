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

variable "transit_encryption_enabled" {
  type        = bool
  default     = true
  description = "Enable in-transit TLS encryption. Set false for dev (no TLS, no auth_token)."
}

variable "transit_encryption_mode" {
  type        = string
  default     = "required"
  description = "TLS mode: 'required' or 'preferred'. Only used when transit_encryption_enabled = true. Note: 'preferred' cannot be combined with auth_token."

  validation {
    condition     = contains(["required", "preferred"], var.transit_encryption_mode)
    error_message = "transit_encryption_mode must be 'required' or 'preferred'."
  }
}

variable "auth_token" {
  type        = string
  default     = null
  sensitive   = true
  description = "Redis AUTH token (password). Only supported when transit_encryption_enabled = true and transit_encryption_mode = 'required'."
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
