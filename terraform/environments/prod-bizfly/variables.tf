variable "project_name" {
  type = string
}

variable "enable_app_bootstrap" {
  type    = bool
  default = false
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "bizfly_api_token" {
  type      = string
  sensitive = true
}

variable "kubeconfig_path" {
  type = string
}

variable "kubeconfig_context" {
  type = string
}

variable "domain" {
  type = string
}

variable "ingress_class_name" {
  type    = string
  default = "nginx"
}

variable "enable_ingress" {
  type    = bool
  default = true
}

variable "service_hosts" {
  type    = map(string)
  default = {}
}

variable "common_env" {
  type    = map(string)
  default = {}
}

variable "secret_name" {
  type    = string
  default = "app-secrets"
}

variable "secret_data" {
  type      = map(string)
  sensitive = true
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
}

variable "enable_postgres" {
  type    = bool
  default = true
}

variable "external_postgres_host" {
  type    = string
  default = ""
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "db_port" {
  type    = number
  default = 5432
}

variable "postgres_release_name" {
  type    = string
  default = "postgres"
}

variable "postgres_chart_version" {
  type    = string
  default = "15.5.38"
}

variable "postgres_storage_size" {
  type    = string
  default = "20Gi"
}

variable "enable_redis" {
  type    = bool
  default = true
}

variable "external_redis_host" {
  type    = string
  default = ""
}

variable "redis_password" {
  type      = string
  sensitive = true
}

variable "redis_port" {
  type    = number
  default = 6379
}

variable "redis_release_name" {
  type    = string
  default = "redis"
}

variable "redis_chart_version" {
  type    = string
  default = "20.11.3"
}

variable "redis_storage_size" {
  type    = string
  default = "8Gi"
}

variable "enable_object_storage" {
  type    = bool
  default = true
}

variable "external_object_storage_endpoint" {
  type    = string
  default = ""
}

variable "object_storage_release_name" {
  type    = string
  default = "minio"
}

variable "object_storage_chart_version" {
  type    = string
  default = "14.10.4"
}

variable "object_storage_storage_size" {
  type    = string
  default = "100Gi"
}

variable "object_storage_root_user" {
  type    = string
  default = "minioadmin"
}

variable "object_storage_root_password" {
  type      = string
  sensitive = true
}

variable "object_storage_port" {
  type    = number
  default = 9000
}

variable "object_storage_buckets" {
  type    = list(string)
  default = ["app-public", "app-private"]
}

variable "object_storage_ingress_enabled" {
  type    = bool
  default = false
}

variable "object_storage_ingress_hostname" {
  type    = string
  default = ""
}

