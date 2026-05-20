terraform {
  required_version = ">= 1.10.0"

  required_providers {
    bizflycloud = {
      source  = "bizflycloud/bizflycloud"
      version = ">= 0.0.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.14"
    }
  }
}

# Keep bizflycloud provider configured for future managed resources (LB, DBaaS, etc.).
provider "bizflycloud" {
  token = var.bizfly_api_token
}

provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kubeconfig_context
}

provider "helm" {
  kubernetes {
    config_path    = var.kubeconfig_path
    config_context = var.kubeconfig_context
  }
}

locals {
  namespace = "${var.project_name}-${var.environment}"
}

module "app_stack" {
  count  = var.enable_app_bootstrap ? 1 : 0
  source = "../../modules/k8s-app-stack"

  project_name       = var.project_name
  environment        = var.environment
  namespace          = local.namespace
  domain             = var.domain
  ingress_class_name = var.ingress_class_name
  enable_ingress     = var.enable_ingress
  service_hosts      = var.service_hosts
  common_env         = var.common_env

  secret_name = var.secret_name
  secret_data = var.secret_data

  services = var.services

  enable_postgres        = var.enable_postgres
  external_postgres_host = var.external_postgres_host
  postgres = {
    release_name  = var.postgres_release_name
    chart_version = var.postgres_chart_version
    storage_size  = var.postgres_storage_size
    username      = var.db_username
    password      = var.db_password
    database      = var.db_name
    service_port  = var.db_port
  }

  enable_redis        = var.enable_redis
  external_redis_host = var.external_redis_host
  redis = {
    release_name  = var.redis_release_name
    chart_version = var.redis_chart_version
    storage_size  = var.redis_storage_size
    password      = var.redis_password
    service_port  = var.redis_port
  }

  enable_object_storage            = var.enable_object_storage
  external_object_storage_endpoint = var.external_object_storage_endpoint
  object_storage = {
    release_name     = var.object_storage_release_name
    chart_version    = var.object_storage_chart_version
    storage_size     = var.object_storage_storage_size
    root_user        = var.object_storage_root_user
    root_password    = var.object_storage_root_password
    service_port     = var.object_storage_port
    buckets          = var.object_storage_buckets
    ingress_enabled  = var.object_storage_ingress_enabled
    ingress_hostname = var.object_storage_ingress_hostname
  }
}

output "namespace" {
  value = var.enable_app_bootstrap ? module.app_stack[0].namespace : null
}

output "deployment_names" {
  value = var.enable_app_bootstrap ? module.app_stack[0].deployment_names : {}
}

output "service_names" {
  value = var.enable_app_bootstrap ? module.app_stack[0].service_names : {}
}

output "ingress_hosts" {
  value = var.enable_app_bootstrap ? module.app_stack[0].ingress_hosts : {}
}

output "postgres_host" {
  value = var.enable_app_bootstrap ? module.app_stack[0].postgres_host : null
}

output "redis_host" {
  value = var.enable_app_bootstrap ? module.app_stack[0].redis_host : null
}

output "app_secret_name" {
  value = var.enable_app_bootstrap ? module.app_stack[0].app_secret_name : null
}

output "object_storage_endpoint" {
  value = var.enable_app_bootstrap ? module.app_stack[0].object_storage_endpoint : null
}

output "object_storage_buckets" {
  value = var.enable_app_bootstrap ? module.app_stack[0].object_storage_buckets : []
}

