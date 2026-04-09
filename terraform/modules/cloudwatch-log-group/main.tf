################################
# CloudWatch Log Groups (one per ECS service)
################################

resource "aws_cloudwatch_log_group" "services" {
  for_each = var.services

  name              = "/aws/ecs/aws-sg-${var.project_name}-${var.environment}-logs-${each.value.name}"
  retention_in_days = var.retention_in_days

  tags = var.tags
}
