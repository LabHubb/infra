################################
# Secrets Manager – single secret, JSON key/value store
#
# All secrets are combined into ONE secret name:
#   {name_prefix}/{secret_name}   e.g. labhub-dev/app-secrets
#
# The secret value is a JSON object:
#   { "DB_PASSWORD": "...", "REDIS_AUTH_TOKEN": "...", ... }
#
# ECS containers reference individual keys via the versioned ARN + JSON key suffix:
#   arn:aws:secretsmanager:...:secret:labhub-dev/app-secrets-xxxxx::DB_PASSWORD
################################

resource "aws_secretsmanager_secret" "this" {
  name                    = "${var.project_name}-${var.environment}/${var.secret_name}"
  description             = var.description
  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}/${var.secret_name}"
  })
}

resource "aws_secretsmanager_secret_version" "this" {
  secret_id = aws_secretsmanager_secret.this.id

  # All key/value pairs serialised as a single JSON string
  secret_string = jsonencode({
    for k, v in var.secrets : k => v.value
  })
}
