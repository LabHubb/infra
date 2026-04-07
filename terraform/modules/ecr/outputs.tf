output "repository_urls" {
  description = "Map of service name → ECR repository URL. Empty map when enable_ecr = false."
  value       = { for k, v in aws_ecr_repository.this : k => v.repository_url }
}

output "repository_arns" {
  description = "Map of service name → ECR repository ARN. Empty map when enable_ecr = false."
  value       = { for k, v in aws_ecr_repository.this : k => v.arn }
}

output "registry_id" {
  description = "AWS account ID that owns the ECR registry. Empty string when enable_ecr = false."
  value       = length(aws_ecr_repository.this) > 0 ? values(aws_ecr_repository.this)[0].registry_id : ""
}
