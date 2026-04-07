################################
# Secrets Manager – one secret per logical key
# Stores DB password, Redis auth token, etc.
################################

resource "aws_secretsmanager_secret" "secrets" {
  for_each = var.secrets

  name                    = "${var.name_prefix}/${each.key}"
  description             = lookup(each.value, "description", "Managed by Terraform")
  recovery_window_in_days = var.recovery_window_in_days

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "secrets" {
  for_each = var.secrets

  secret_id     = aws_secretsmanager_secret.secrets[each.key].id
  secret_string = each.value.value
}
