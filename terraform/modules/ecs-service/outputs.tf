output "service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.this.name
}

output "service_id" {
  description = "ECS service ID"
  value       = aws_ecs_service.this.id
}

output "task_definition_arn" {
  description = "ECS task definition ARN"
  value       = aws_ecs_task_definition.this.arn
}

output "task_role_arn" {
  description = "IAM task role ARN"
  value       = aws_iam_role.task.arn
}

output "execution_role_arn" {
  description = "IAM execution role ARN"
  value       = aws_iam_role.execution.arn
}
