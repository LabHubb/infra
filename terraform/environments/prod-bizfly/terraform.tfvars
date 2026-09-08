project_name = "labhub"
environment  = "prod"

# Do not pre-install workloads via Terraform; install app charts manually later.
enable_app_bootstrap = false

# BizflyCloud API token (recommended to pass via TF_VAR_bizfly_api_token)
bizfly_api_token = ""

# Kubeconfig pointing to your Bizfly Kubernetes cluster
kubeconfig_path    = "~/.kube/config"
kubeconfig_context = "bizfly-prod"

domain             = "example.com"
ingress_class_name = "nginx"
enable_ingress     = true

service_hosts = {
  be_app      = "api.example.com"
  be_admin    = "admin-api.example.com"
  fe_admin    = "admin.example.com"
  fe_customer = "app.example.com"
}

common_env = {
  APP_ENV = "production"
}

# One secret object storing key/value pairs
secret_name = "app-secrets"
secret_data = {
  DB_PASSWORD          = "replace-me"
  REDIS_PASSWORD       = "replace-me"
  PAYMENT_CLIENT_ID    = "replace-me"
  PAYMENT_API_KEY      = "replace-me"
  PAYMENT_CHECKSUM_KEY = "replace-me"
  FCM_PROJECT_ID       = "replace-me"
  FCM_PRIVATE_KEY      = "replace-me"
  FCM_CLIENT_EMAIL     = "replace-me"
}

services = {
  be_app = {
    name              = "be-app"
    image             = "registry.example.com/labhub-be-app:latest"
    container_port    = 8080
    replicas          = 2
    path_pattern      = "/api"
    health_check_path = "/api/v1/health"
    public            = true
    env = {
      DATABASE_SSLMODE = "disable"
    }
  }

  be_admin = {
    name              = "be-admin"
    image             = "registry.example.com/labhub-be-admin:latest"
    container_port    = 8080
    replicas          = 2
    path_pattern      = "/admin/api"
    # Matches APP_BASE_PATH below: the readiness/liveness probes hit the pod's
    # container port directly, so the /admin/api Ingress prefix must not appear here.
    health_check_path = "/api/v1/health"
    public            = true
    env = {
      DATABASE_SSLMODE = "disable"
      # APP_PORT overrides be-admin's own default of 8081 to match container_port.
      # APP_BASE_PATH stays at the app's default: be-admin serves /api/v1.
      # The Ingress forwards /admin/api through unchanged (no rewrite annotation),
      # so that prefix has to be stripped upstream for requests to reach these
      # routes — handled outside this file.
      APP_PORT      = "8080"
      APP_BASE_PATH = "/api/v1"
    }
  }

  fe_admin = {
    name              = "fe-admin"
    image             = "registry.example.com/labhub-fe-admin:latest"
    container_port    = 3000
    replicas          = 2
    path_pattern      = "/admin"
    health_check_path = "/"
    public            = true
    env = {
      APP_PORT = "3000"
    }
  }

  fe_customer = {
    name              = "fe-customer"
    image             = "registry.example.com/labhub-fe-customer:latest"
    container_port    = 3000
    replicas          = 2
    path_pattern      = "/"
    health_check_path = "/"
    public            = true
    env = {
      APP_PORT = "3000"
    }
  }
}

# Set false if using managed DB/Redis on Bizfly and provide external hosts below.
enable_postgres        = true
external_postgres_host = ""
db_name                = "labhub"
db_username            = "labhub_admin"
db_password            = "replace-me"
db_port                = 5432
postgres_release_name  = "postgres"
postgres_chart_version = "15.5.38"
postgres_storage_size  = "20Gi"

enable_redis        = true
external_redis_host = ""
redis_password      = "replace-me"
redis_port          = 6379
redis_release_name  = "redis"
redis_chart_version = "20.11.3"
redis_storage_size  = "8Gi"

# S3 equivalent on Kubernetes (MinIO) to mirror AWS S3 usage.
# Set enable_object_storage = false when using Bizfly managed Object Storage,
# then provide external_object_storage_endpoint.
enable_object_storage            = true
external_object_storage_endpoint = ""
object_storage_release_name      = "minio"
object_storage_chart_version     = "14.10.4"
object_storage_storage_size      = "200Gi"
object_storage_root_user         = "labhub"
object_storage_root_password     = "replace-me"
object_storage_port              = 9000
object_storage_buckets = [
  "aws-sg-labhub-prod-s3-bucket-001",
  "aws-sg-labhub-prod-s3-bucket-002",
]
object_storage_ingress_enabled  = false
object_storage_ingress_hostname = ""

