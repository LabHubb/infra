locals {
  full_prefix = "${var.project_name}-${var.environment}"

  postgres_host           = var.enable_postgres ? "${var.postgres.release_name}-postgresql.${var.namespace}.svc.cluster.local" : var.external_postgres_host
  redis_host              = var.enable_redis ? "${var.redis.release_name}-master.${var.namespace}.svc.cluster.local" : var.external_redis_host
  object_storage_endpoint = var.enable_object_storage ? "http://${var.object_storage.release_name}.${var.namespace}.svc.cluster.local:${var.object_storage.service_port}" : var.external_object_storage_endpoint

  auto_env = {
    DATABASE_HOST     = local.postgres_host
    DATABASE_PORT     = tostring(var.postgres.service_port)
    DATABASE_USER     = var.postgres.username
    DATABASE_NAME     = var.postgres.database
    REDIS_HOST        = local.redis_host
    REDIS_PORT        = tostring(var.redis.service_port)
    S3_ENDPOINT       = local.object_storage_endpoint
    S3_BUCKET_PUBLIC  = try(var.object_storage.buckets[0], "")
    S3_BUCKET_PRIVATE = try(var.object_storage.buckets[1], "")
    APP_SECRET_NAME   = var.secret_name
  }

  service_hosts = {
    for k, v in var.services : k => lookup(var.service_hosts, k, "${v.name}.${var.domain}")
  }

  public_services = {
    for k, v in var.services : k => v if v.public
  }
}

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.namespace
    labels = {
      project     = var.project_name
      environment = var.environment
    }
  }
}

resource "kubernetes_secret_v1" "app" {
  metadata {
    name      = var.secret_name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  data = var.secret_data

  type = "Opaque"
}

resource "helm_release" "postgres" {
  count      = var.enable_postgres ? 1 : 0
  name       = var.postgres.release_name
  namespace  = kubernetes_namespace_v1.this.metadata[0].name
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"
  version    = var.postgres.chart_version

  set {
    name  = "global.postgresql.auth.username"
    value = var.postgres.username
  }

  set {
    name  = "global.postgresql.auth.password"
    value = var.postgres.password
  }

  set {
    name  = "global.postgresql.auth.database"
    value = var.postgres.database
  }

  set {
    name  = "primary.persistence.size"
    value = var.postgres.storage_size
  }
}

resource "helm_release" "redis" {
  count      = var.enable_redis ? 1 : 0
  name       = var.redis.release_name
  namespace  = kubernetes_namespace_v1.this.metadata[0].name
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "redis"
  version    = var.redis.chart_version

  set {
    name  = "auth.enabled"
    value = "true"
  }

  set {
    name  = "auth.password"
    value = var.redis.password
  }

  set {
    name  = "master.persistence.size"
    value = var.redis.storage_size
  }
}

resource "helm_release" "object_storage" {
  count      = var.enable_object_storage ? 1 : 0
  name       = var.object_storage.release_name
  namespace  = kubernetes_namespace_v1.this.metadata[0].name
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "minio"
  version    = var.object_storage.chart_version

  set {
    name  = "auth.rootUser"
    value = var.object_storage.root_user
  }

  set {
    name  = "auth.rootPassword"
    value = var.object_storage.root_password
  }

  set {
    name  = "defaultBuckets"
    value = join(",", var.object_storage.buckets)
  }

  set {
    name  = "persistence.size"
    value = var.object_storage.storage_size
  }

  set {
    name  = "service.ports.api"
    value = tostring(var.object_storage.service_port)
  }

  set {
    name  = "ingress.enabled"
    value = var.object_storage.ingress_enabled ? "true" : "false"
  }

  set {
    name  = "ingress.hostname"
    value = var.object_storage.ingress_hostname
  }
}

resource "kubernetes_deployment_v1" "services" {
  for_each = var.services

  metadata {
    name      = "${var.project_name}-${each.value.name}-${var.environment}"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels = {
      app = each.value.name
    }
  }

  spec {
    replicas = each.value.replicas

    selector {
      match_labels = {
        app = each.value.name
      }
    }

    template {
      metadata {
        labels = {
          app = each.value.name
        }
      }

      spec {
        container {
          name  = each.value.name
          image = each.value.image

          port {
            container_port = each.value.container_port
          }

          dynamic "env" {
            for_each = merge(var.common_env, local.auto_env, each.value.env)
            content {
              name  = env.key
              value = env.value
            }
          }

          dynamic "env" {
            for_each = nonsensitive(keys(var.secret_data))
            content {
              name = env.value
              value_from {
                secret_key_ref {
                  name = kubernetes_secret_v1.app.metadata[0].name
                  key  = env.value
                }
              }
            }
          }

          readiness_probe {
            http_get {
              path = each.value.health_check_path
              port = each.value.container_port
            }
            initial_delay_seconds = 15
            period_seconds        = 10
          }

          liveness_probe {
            http_get {
              path = each.value.health_check_path
              port = each.value.container_port
            }
            initial_delay_seconds = 30
            period_seconds        = 15
          }

          resources {
            requests = {
              cpu    = each.value.resources.cpu_request
              memory = each.value.resources.memory_request
            }
            limits = {
              cpu    = each.value.resources.cpu_limit
              memory = each.value.resources.memory_limit
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_secret_v1.app,
    helm_release.postgres,
    helm_release.redis,
    helm_release.object_storage,
  ]
}

resource "kubernetes_service_v1" "services" {
  for_each = var.services

  metadata {
    name      = each.value.name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {
    selector = {
      app = each.value.name
    }

    port {
      port        = each.value.container_port
      target_port = each.value.container_port
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "public" {
  count = var.enable_ingress ? 1 : 0

  metadata {
    name      = "${local.full_prefix}-ingress"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"                    = var.ingress_class_name
      "nginx.ingress.kubernetes.io/proxy-body-size"    = "50m"
      "nginx.ingress.kubernetes.io/proxy-read-timeout" = "120"
    }
  }

  spec {
    ingress_class_name = var.ingress_class_name

    dynamic "rule" {
      for_each = local.public_services
      content {
        host = local.service_hosts[rule.key]
        http {
          path {
            path      = rule.value.path_pattern
            path_type = "Prefix"
            backend {
              service {
                name = kubernetes_service_v1.services[rule.key].metadata[0].name
                port {
                  number = rule.value.container_port
                }
              }
            }
          }
        }
      }
    }
  }
}

