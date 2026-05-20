output "namespace" {
  value       = kubernetes_namespace_v1.this.metadata[0].name
  description = "Kubernetes namespace"
}

output "service_names" {
  value       = { for k, v in kubernetes_service_v1.services : k => v.metadata[0].name }
  description = "Service names"
}

output "deployment_names" {
  value       = { for k, v in kubernetes_deployment_v1.services : k => v.metadata[0].name }
  description = "Deployment names"
}

output "ingress_name" {
  value       = var.enable_ingress ? kubernetes_ingress_v1.public[0].metadata[0].name : null
  description = "Ingress name"
}

output "ingress_hosts" {
  value       = { for k, v in var.services : k => lookup(var.service_hosts, k, "${v.name}.${var.domain}") if v.public }
  description = "Ingress hosts by service"
}

output "postgres_host" {
  value       = local.postgres_host
  description = "Postgres host visible from pods"
}

output "redis_host" {
  value       = local.redis_host
  description = "Redis host visible from pods"
}

output "app_secret_name" {
  value       = kubernetes_secret_v1.app.metadata[0].name
  description = "Kubernetes secret used by all services"
}

output "object_storage_endpoint" {
  value       = local.object_storage_endpoint
  description = "S3-compatible endpoint visible from pods"
}

output "object_storage_buckets" {
  value       = var.object_storage.buckets
  description = "S3-compatible bucket names"
}

