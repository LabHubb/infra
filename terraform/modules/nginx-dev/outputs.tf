output "nginx_service_name" {
  description = "ECS service name for the nginx reverse proxy"
  value       = aws_ecs_service.nginx.name
}

output "nginx_task_definition_arn" {
  description = "ECS task definition ARN for nginx"
  value       = aws_ecs_task_definition.nginx.arn
}

output "nginx_log_group_name" {
  description = "CloudWatch log group name for nginx"
  value       = aws_cloudwatch_log_group.nginx.name
}
