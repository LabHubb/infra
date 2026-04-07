output "secret_arn" {
  description = "ARN of the single combined secret (labhub-dev/app-secrets)"
  value       = aws_secretsmanager_secret.this.arn
}

output "secret_name" {
  description = "Full secret name in AWS Secrets Manager (e.g. labhub-dev/app-secrets)"
  value       = aws_secretsmanager_secret.this.name
}

output "secret_arns" {
  description = "Map of key → versioned ARN with JSON key suffix for direct ECS task definition injection. Format: arn:...:secret:name-xxxxx::KEY"
  value = {
    for k in keys(var.secrets) :
    k => "${aws_secretsmanager_secret.this.arn}::${k}::"
  }
}
