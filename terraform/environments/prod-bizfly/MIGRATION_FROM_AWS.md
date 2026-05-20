# AWS Prod -> Bizfly Kubernetes Migration Inventory

This inventory is derived from `terraform/environments/prod/terraform.tfvars` and mapped into `terraform/environments/prod-bizfly/terraform.tfvars`.

## Services

- `be-app` -> `services.be_app`
- `be-admin` -> `services.be_admin`
- `fe-admin` -> `services.fe_admin`
- `fe-customer` -> `services.fe_customer`

All services keep production replicas (`2`) and health check paths.

## Data components

- PostgreSQL
  - AWS: `db.t4g.small` RDS
  - Bizfly stack: Helm PostgreSQL by default (`enable_postgres = true`), or external managed endpoint

- Redis
  - AWS: `cache.t4g.small` ElastiCache
  - Bizfly stack: Helm Redis by default (`enable_redis = true`), or external managed endpoint

- Object storage
  - AWS: two S3 buckets
    - `aws-sg-labhub-prod-s3-bucket-001`
    - `aws-sg-labhub-prod-s3-bucket-002`
  - Bizfly stack: MinIO bucket list mirrors the same names by default (`enable_object_storage = true`)

## Networking and ingress

- AWS ALB + listener rules -> Kubernetes Ingress
- Route53 records -> `service_hosts` hostnames; DNS is updated to ingress externally

## Secrets

- AWS Secrets Manager single secret -> Kubernetes secret `app-secrets`
- Keys preserved as key/value entries (for example `DB_PASSWORD`, `REDIS_PASSWORD`)

## Registry and images

- AWS ECR is replaced with registry-agnostic image URLs in `services[*].image`
- Update each image to your Bizfly-compatible registry before final cutover

## Cutover checklist

1. Deploy `prod-bizfly` stack in parallel.
2. Validate app connectivity to Postgres/Redis/object storage.
3. Push and verify production container images in target registry.
4. Update DNS records to ingress endpoint.
5. Observe traffic and logs, then decommission AWS prod.

