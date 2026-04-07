variable "name_prefix" {
  type        = string
  description = "Prefix for all resource names"
}

variable "bucket_suffix" {
  type        = string
  description = "Suffix appended to name_prefix for the bucket name (e.g. 'files')"
}

variable "noncurrent_version_expiration_days" {
  type        = number
  default     = 365
  description = "Days after which noncurrent versions are permanently deleted"
}

variable "cors_allowed_origins" {
  type        = list(string)
  default     = []
  description = "List of allowed CORS origins. Leave empty to skip CORS config."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to all resources"
}
