output "scheduler_role_arn" {
  description = "IAM role ARN used by EventBridge Scheduler"
  value       = aws_iam_role.scheduler.arn
}

output "schedule_group_name" {
  description = "EventBridge Scheduler group name"
  value       = aws_scheduler_schedule_group.this.name
}

output "ecs_start_schedule_arns" {
  description = "ARNs of ECS start schedules"
  value       = { for k, v in aws_scheduler_schedule.ecs_start : k => v.arn }
}

output "ecs_stop_schedule_arns" {
  description = "ARNs of ECS stop schedules"
  value       = { for k, v in aws_scheduler_schedule.ecs_stop : k => v.arn }
}
