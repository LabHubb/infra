# Prod on Bizfly Kubernetes

This environment migrates your AWS production stack into a Kubernetes-first runtime on BizflyCloud.

By default, this environment does **not** install application workloads into Kubernetes.
Set `enable_app_bootstrap = true` only if you want Terraform to create Deployments/Services/Ingress and data Helm releases.
If you deploy by Helm manually, keep `enable_app_bootstrap = false`.

## Migrated component map

| AWS production component | Bizfly/Kubernetes target in this stack | Status |
|---|---|---|
| ECS cluster (EC2 launch type) | Kubernetes cluster workloads (`Deployment` + `Service`) | migrated |
| ECS services (`be-app`, `be-admin`, `fe-admin`, `fe-customer`) | Same services from `services` map | migrated |
| ALB + listener rules | Kubernetes Ingress (nginx ingress class) | migrated |
| RDS PostgreSQL | Bitnami PostgreSQL Helm release or external managed Postgres | migrated |
| ElastiCache Redis | Bitnami Redis Helm release or external managed Redis | migrated |
| S3 buckets | S3-compatible MinIO Helm release + bucket list | migrated |
| Secrets Manager single secret | Kubernetes secret `app-secrets` (key/value) | migrated |
| Route53 records | DNS hostnames in `service_hosts` (point your DNS to ingress LB) | manual DNS cutover |
| ECR repositories | Use your image registry URLs directly in `services[*].image` | registry-agnostic |

## What it creates

- Namespace: `${project_name}-${environment}`
- One Kubernetes secret object (`app-secrets`) with key/value pairs
- Deployments and services for each entry in `services`
- Ingress rules for services where `public = true`
- Optional PostgreSQL + Redis + MinIO (S3-compatible object storage) via Helm
- Auto env injection for all services:
  - `DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_USER`, `DATABASE_NAME`
  - `REDIS_HOST`, `REDIS_PORT`
  - `S3_ENDPOINT`, `S3_BUCKET_PUBLIC`, `S3_BUCKET_PRIVATE`
  - `APP_SECRET_NAME`

## Prerequisites

- A running Bizfly Kubernetes cluster and kubeconfig access
- Ingress controller installed (for example ingress-nginx)
- Terraform >= 1.10

## Quick start

```bash
cd terraform/environments/prod-bizfly

terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

When `enable_app_bootstrap = false`, Terraform provisions no in-cluster app resources from this environment.
You can then deploy your own charts with Helm after cluster provisioning.

## Sensitive values

Avoid committing secrets in `terraform.tfvars`.

```bash
export TF_VAR_bizfly_api_token="<your_token>"
export TF_VAR_db_password="<db_password>"
export TF_VAR_redis_password="<redis_password>"
export TF_VAR_object_storage_root_password="<minio_root_password>"
```

## Managed service mode (recommended for production)

If you use Bizfly managed services instead of in-cluster Helm charts:

- Postgres: set `enable_postgres = false` and `external_postgres_host = "..."`
- Redis: set `enable_redis = false` and `external_redis_host = "..."`
- Object storage: set `enable_object_storage = false` and `external_object_storage_endpoint = "..."`

Applications still receive all endpoint env vars automatically.

## DNS cutover

- Keep `service_hosts` set to production hosts (`api.example.com`, `admin.example.com`, `app.example.com`)
- Get your ingress external endpoint from your cluster
- Update DNS records in your DNS provider to point those hosts to the ingress endpoint

