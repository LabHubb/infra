################################################################################
# Auto Stop/Start Scheduler
#
# Schedules:
 #   Start  → 01:00 UTC  (08:00 GMT+7)  Mon-Fri
#   Stop   → 11:00 UTC  (18:00 GMT+7)  Mon-Fri
#
# Targets:
#   * ECS services        - UpdateService desiredCount 0 / original
#   * ASG (ECS EC2 nodes) - UpdateAutoScalingGroup min/max/desired 0 / original
#   * RDS instance        - StopDBInstance / StartDBInstance
#
# NOTE: ElastiCache Redis (replication groups) does NOT support stop/start via
# the AWS API or EventBridge Scheduler. To save cost, consider deleting and
# recreating the cluster, or use a smaller node type instead.
################################################################################

################################################################################
# IAM Role for EventBridge Scheduler
################################################################################

data "aws_iam_policy_document" "scheduler_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "scheduler" {
  name               = "${var.name_prefix}-scheduler-role"
  assume_role_policy = data.aws_iam_policy_document.scheduler_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "scheduler_policy" {
  # ECS
  statement {
    sid     = "ECSUpdateService"
    actions = ["ecs:UpdateService", "ecs:DescribeServices"]
    resources = [
      "arn:aws:ecs:${var.aws_region}:${var.aws_account_id}:service/${var.ecs_cluster_name}/*"
    ]
  }

  # ASG
  statement {
    sid       = "ASGUpdate"
    actions   = ["autoscaling:UpdateAutoScalingGroup"]
    resources = ["arn:aws:autoscaling:${var.aws_region}:${var.aws_account_id}:autoScalingGroup:*:autoScalingGroupName/${var.asg_name}"]
  }

  # RDS
  statement {
    sid       = "RDSStopStart"
    actions   = ["rds:StopDBInstance", "rds:StartDBInstance"]
    resources = ["arn:aws:rds:${var.aws_region}:${var.aws_account_id}:db:${var.rds_identifier}"]
  }
}

resource "aws_iam_role_policy" "scheduler" {
  name   = "${var.name_prefix}-scheduler-policy"
  role   = aws_iam_role.scheduler.id
  policy = data.aws_iam_policy_document.scheduler_policy.json
}

################################################################################
# EventBridge Scheduler Group
################################################################################

resource "aws_scheduler_schedule_group" "this" {
  name = "${var.name_prefix}-dev-schedules"
  tags = var.tags
}

################################################################################
# Helpers – local for schedule expression
# Mon–Fri only (cron: min hour ? * MON-FRI *)
################################################################################

locals {
  start_cron = "cron(0 1 ? * MON-FRI *)"  # 01:00 UTC = 08:00 GMT+7
  stop_cron  = "cron(0 11 ? * MON-FRI *)" # 11:00 UTC = 18:00 GMT+7
}

################################################################################
# ECS Services – START (restore desired_count per service)
################################################################################

resource "aws_scheduler_schedule" "ecs_start" {
  for_each = var.ecs_services

  name       = "${var.name_prefix}-ecs-${each.key}-start"
  group_name = aws_scheduler_schedule_group.this.name

  schedule_expression          = local.start_cron
  schedule_expression_timezone = "UTC"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ecs:updateService"
    role_arn = aws_iam_role.scheduler.arn

    input = jsonencode({
      Cluster      = var.ecs_cluster_name
      Service      = each.value.service_name
      DesiredCount = each.value.desired_count
    })
  }
}

################################################################################
# ECS Services – STOP (set desired_count = 0)
################################################################################

resource "aws_scheduler_schedule" "ecs_stop" {
  for_each = var.ecs_services

  name       = "${var.name_prefix}-ecs-${each.key}-stop"
  group_name = aws_scheduler_schedule_group.this.name

  schedule_expression          = local.stop_cron
  schedule_expression_timezone = "UTC"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ecs:updateService"
    role_arn = aws_iam_role.scheduler.arn

    input = jsonencode({
      Cluster      = var.ecs_cluster_name
      Service      = each.value.service_name
      DesiredCount = 0
    })
  }
}

################################################################################
# ASG (ECS EC2 nodes) – START (restore capacity)
################################################################################

resource "aws_scheduler_schedule" "asg_start" {
  name       = "${var.name_prefix}-asg-start"
  group_name = aws_scheduler_schedule_group.this.name

  # Restore ASG 5 minutes BEFORE ECS services start so instances are ready
  schedule_expression          = "cron(55 0 ? * MON-FRI *)" # 00:55 UTC
  schedule_expression_timezone = "UTC"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:autoscaling:updateAutoScalingGroup"
    role_arn = aws_iam_role.scheduler.arn

    input = jsonencode({
      AutoScalingGroupName = var.asg_name
      MinSize              = var.asg_min_size
      MaxSize              = var.asg_max_size
      DesiredCapacity      = var.asg_desired_capacity
    })
  }
}

################################################################################
# ASG (ECS EC2 nodes) – STOP (scale to 0)
# ECS services must be stopped first (11:00 UTC), ASG scales in 5 min later
################################################################################

resource "aws_scheduler_schedule" "asg_stop" {
  name       = "${var.name_prefix}-asg-stop"
  group_name = aws_scheduler_schedule_group.this.name

  schedule_expression          = "cron(5 11 ? * MON-FRI *)" # 11:05 UTC
  schedule_expression_timezone = "UTC"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:autoscaling:updateAutoScalingGroup"
    role_arn = aws_iam_role.scheduler.arn

    input = jsonencode({
      AutoScalingGroupName = var.asg_name
      MinSize              = 0
      MaxSize              = var.asg_max_size
      DesiredCapacity      = 0
    })
  }
}

################################################################################
# RDS – START
################################################################################

resource "aws_scheduler_schedule" "rds_start" {
  name       = "${var.name_prefix}-rds-start"
  group_name = aws_scheduler_schedule_group.this.name

  schedule_expression          = local.start_cron
  schedule_expression_timezone = "UTC"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:rds:startDBInstance"
    role_arn = aws_iam_role.scheduler.arn

    input = jsonencode({
      DbInstanceIdentifier = var.rds_identifier
    })
  }
}

################################################################################
# RDS – STOP
################################################################################

resource "aws_scheduler_schedule" "rds_stop" {
  name       = "${var.name_prefix}-rds-stop"
  group_name = aws_scheduler_schedule_group.this.name

  schedule_expression          = local.stop_cron
  schedule_expression_timezone = "UTC"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:rds:stopDBInstance"
    role_arn = aws_iam_role.scheduler.arn

    input = jsonencode({
      DbInstanceIdentifier = var.rds_identifier
    })
  }
}

