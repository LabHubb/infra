output "service_name" {
  description = "ECS service name for the Redis container"
  value       = aws_ecs_service.redis.name
}

output "redis_host" {
  description = "Host that other bridge-mode containers on the same EC2 use to reach Redis (Docker bridge gateway)"
  value       = "172.17.0.1"
}

output "redis_port" {
  description = "Redis port published on the EC2 host"
  value       = var.redis_port
}

output "log_group_name" {
  description = "CloudWatch log group name for Redis"
  value       = aws_cloudwatch_log_group.redis.name
}

