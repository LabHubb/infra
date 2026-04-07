output "nginx_sg_id" {
  description = "Security group ID of the nginx EC2 instances"
  value       = aws_security_group.nginx.id
}

output "nginx_asg_name" {
  description = "Auto Scaling Group name for nginx EC2 instances"
  value       = aws_autoscaling_group.nginx.name
}
