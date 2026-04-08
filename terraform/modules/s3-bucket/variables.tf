variable "name_prefix" {
  type        = string
  description = "Prefix for all resource names"
}

variable "buckets" {
  description = "Map of S3 bucket configurations. Key is used as a short identifier."
  type = map(object({
    # -- Naming --
    # Option A: provide 'name' to use an exact bucket name (ignores suffix + name_prefix).
    # Option B: provide 'suffix' to auto-build: <name_prefix>-<suffix>.
    name   = optional(string, null) # exact full bucket name (overrides suffix)
    suffix = optional(string, "")   # appended to name_prefix when name is null

    # -- Access --
    # "private"       = fully private (Block Public Access ON, no public policy)
    # "public-read"   = static website / public assets (Block Public Access OFF, public-read ACL)
    access = optional(string, "private")

    # -- Versioning --
    versioning_enabled = optional(bool, true)

    # -- Encryption --
    sse_algorithm     = optional(string, "AES256") # "AES256" or "aws:kms"
    kms_master_key_id = optional(string, null)     # only used when sse_algorithm = "aws:kms"

    # -- Lifecycle --
    noncurrent_version_transition_ia_days      = optional(number, 30)  # days before STANDARD_IA
    noncurrent_version_transition_glacier_days = optional(number, 90)  # days before GLACIER
    noncurrent_version_expiration_days         = optional(number, 365) # days before permanent delete
    abort_incomplete_multipart_days            = optional(number, 7)

    # -- CORS --
    cors_allowed_origins  = optional(list(string), [])
    cors_allowed_methods  = optional(list(string), ["GET", "PUT", "POST", "DELETE", "HEAD"])
    cors_allowed_headers  = optional(list(string), ["*"])
    cors_expose_headers   = optional(list(string), [])
    cors_max_age_seconds  = optional(number, 3600)

    # -- Static website --
    website_enabled    = optional(bool, false)
    website_index_page = optional(string, "index.html")
    website_error_page = optional(string, "error.html")
  }))
  default = {}
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to every bucket and related resource"
}
