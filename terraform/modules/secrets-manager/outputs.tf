output "secret_arns" {
  description = "Map of secret key to ARN"
  value       = { for k, v in aws_secretsmanager_secret.secrets : k => v.arn }
}

output "secret_names" {
  description = "Map of secret key to full secret name in Secrets Manager"
  value       = { for k, v in aws_secretsmanager_secret.secrets : k => v.name }
}
