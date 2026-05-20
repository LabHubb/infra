variable "project_name" {
  type        = string
  description = "Project name prefix"
}

variable "environment" {
  type        = string
  description = "Environment name (for example: prod)"
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace"
}

variable "domain" {
  type        = string
  description = "Base domain used by ingress hosts"
}

variable "ingress_class_name" {
  type        = string
  default     = "nginx"
  description = "Ingress class name"
}

variable "enable_ingress" {
  type        = bool
  default     = true
  description = "Create ingress for public services"
}

variable "service_hosts" {
  type        = map(string)
  default     = {}
  description = "Optional map of service key => hostname. When omitted, host defaults to <service-name>.<domain>."
}

variable "common_env" {
  type        = map(string)
  default     = {}
  description = "Common non-secret environment variables for all services"
}

variable "secret_name" {
  type        = string
  default     = "app-secrets"
  description = "Kubernetes secret name storing all app secrets as key/value"
}

variable "secret_data" {
  type        = map(string)
  sensitive   = true
  default     = {}
  description = "Secret key/value map (for example DB_PASSWORD, REDIS_PASSWORD)"
}

variable "services" {
  type = map(object({
    name              = string
    image             = string
    container_port    = number
    replicas          = number
    path_pattern      = string
    health_check_path = string
    public            = bool
    env               = optional(map(string), {})
    resources = optional(object({
      cpu_request    = string
      memory_request = string
      cpu_limit      = string
      memory_limit   = string
      }), {
      cpu_request    = "100m"
      memory_request = "128Mi"
      cpu_limit      = "500m"
      memory_limit   = "512Mi"
    })
  }))
  description = "Service definitions"
}

variable "enable_postgres" {
  type        = bool
  default     = true
  description = "Deploy in-cluster Postgres via Helm"
}

variable "postgres" {
  type = object({
    release_name  = string
    chart_version = string
    storage_size  = string
    username      = string
    password      = string
    database      = string
    service_port  = number
  })
  sensitive = true
  default = {
    release_name  = "postgres"
    chart_version = "15.5.38"
    storage_size  = "20Gi"
    username      = "app_user"
    password      = "change-me"
    database      = "app"
    service_port  = 5432
  }
}

variable "external_postgres_host" {
  type        = string
  default     = ""
  description = "External Postgres host when enable_postgres = false"
}

variable "enable_redis" {
  type        = bool
  default     = true
  description = "Deploy in-cluster Redis via Helm"
}

variable "redis" {
  type = object({
    release_name  = string
    chart_version = string
    storage_size  = string
    password      = string
    service_port  = number
  })
  sensitive = true
  default = {
    release_name  = "redis"
    chart_version = "20.11.3"
    storage_size  = "8Gi"
    password      = "change-me"
    service_port  = 6379
  }
}

variable "external_redis_host" {
  type        = string
  default     = ""
  description = "External Redis host when enable_redis = false"
}

variable "enable_object_storage" {
  type        = bool
  default     = true
  description = "Deploy in-cluster object storage (S3-compatible MinIO) via Helm"
}

variable "object_storage" {
  type = object({
    release_name     = string
    chart_version    = string
    storage_size     = string
    root_user        = string
    root_password    = string
    service_port     = number
    buckets          = list(string)
    ingress_enabled  = bool
    ingress_hostname = string
  })
  sensitive = true
  default = {
    release_name     = "minio"
    chart_version    = "14.10.4"
    storage_size     = "100Gi"
    root_user        = "minioadmin"
    root_password    = "change-me-now"
    service_port     = 9000
    buckets          = ["app-public", "app-private"]
    ingress_enabled  = false
    ingress_hostname = ""
  }
}

variable "external_object_storage_endpoint" {
  type        = string
  default     = ""
  description = "External S3 endpoint when enable_object_storage = false"
}

