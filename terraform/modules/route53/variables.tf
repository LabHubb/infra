variable "hosted_zone_name" {
  type        = string
  description = "Route53 hosted zone name (e.g. example.com)"
}

variable "alb_dns_name" {
  type        = string
  default     = ""
  description = "ALB DNS name. Set to empty string in dev to use ip_addresses instead."
}

variable "alb_zone_id" {
  type        = string
  default     = ""
  description = "ALB hosted zone ID (required when alb_dns_name is set)"
}

variable "ip_addresses" {
  type        = list(string)
  default     = []
  description = "List of EC2 public IPs for direct A records (dev/nginx). Used when alb_dns_name is empty."
}

variable "service_dns_records" {
  type = map(object({
    subdomain = string
  }))
  description = "Map of service key to DNS subdomain. E.g. { be = { subdomain = 'api.dev' } }"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags (kept for consistency)"
}
