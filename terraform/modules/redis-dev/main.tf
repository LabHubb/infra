################################################################################
# Redis ECS Service – Dev
#
# Architecture:
#   redis task  → network_mode = "bridge" → publishes port 6379 on the EC2 host
#   app tasks   → network_mode = "bridge" → reach Redis via the Docker bridge
#                                           gateway: 172.17.0.1:6379
#
# Why 172.17.0.1 works:
#   Docker bridge mode with a fixed hostPort binds the container port to
#   0.0.0.0:<hostPort> on the EC2 host.
#   Other bridge-mode containers reach the host via the docker0 gateway IP
#   (172.17.0.1 by default on Linux / ECS-optimised AMIs).
#
#   be-app (bridge) → 172.17.0.1:6379
#              ↓
#   Docker NAT rule: 0.0.0.0:6379 → redis container:6379  ✓
#
#   nginx (host net) can also reach Redis via 127.0.0.1:6379 if needed.
#
# No IAM task role is attached – Redis does not call any AWS APIs.
# An execution role is still needed to pull the image and write CloudWatch logs.
################################################################################

locals {
  full_name = "${var.project_name}-redis-${var.environment}"
}

################################################################################
# CloudWatch Log Group
################################################################################

resource "aws_cloudwatch_log_group" "redis" {
  name              = "/aws/ecs/${var.project_name}/${var.environment}/redis"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

################################################################################
# IAM – Task Execution Role (pull image + write logs)
################################################################################

data "aws_iam_policy_document" "exec_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "exec" {
  name               = "${var.name_prefix}-redis-exec-role"
  assume_role_policy = data.aws_iam_policy_document.exec_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "exec" {
  role       = aws_iam_role.exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

################################################################################
# ECS Task Definition
################################################################################

resource "aws_ecs_task_definition" "redis" {
  family                   = local.full_name
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.exec.arn
  # No task_role_arn – Redis does not call any AWS APIs at runtime.

  cpu    = var.cpu
  memory = var.memory

  container_definitions = jsonencode([{
    name      = "redis"
    image     = var.redis_image
    essential = true
    cpu       = var.cpu
    memory    = var.memory

    # Build the redis-server command:
    #   --requirepass   → enforce AUTH when a password is provided
    #   --save ""       → disable RDB persistence (dev: no disk snapshots, avoids
    #                     the "memory overcommit" warning and speeds up shutdown)
    #   --appendonly no → disable AOF persistence (dev only)
    command = concat(
      ["redis-server"],
      var.redis_password != "" ? ["--requirepass", var.redis_password] : [],
      ["--save", "", "--appendonly", "no"]
    )

    # Expose the password as an env var so the health-check script can authenticate.
    # (The value is already sensitive in the task definition; it does NOT appear
    #  in CloudWatch logs.)
    environment = var.redis_password != "" ? [
      { name = "REDIS_PASSWORD", value = var.redis_password }
    ] : []

    # Fixed host port = container port.
    # Publishes 0.0.0.0:6379 on the EC2 host so other bridge-mode containers
    # can reach Redis via 172.17.0.1:6379 (docker0 bridge gateway).
    portMappings = [
      {
        containerPort = var.redis_port
        hostPort      = var.redis_port
        protocol      = "tcp"
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.redis.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "redis"
      }
    }

    # Auth-aware health check:
    #   - With password: redis-cli -a <pass> ping  → must return PONG
    #   - Without password: redis-cli ping          → must return PONG
    healthCheck = {
      command = [
        "CMD-SHELL",
        var.redis_password != "" ? "redis-cli -a \"$REDIS_PASSWORD\" ping | grep -q PONG || exit 1" : "redis-cli ping | grep -q PONG || exit 1"
      ]
      interval    = 15
      timeout     = 5
      retries     = 3
      startPeriod = 15
    }
  }])

  tags = var.tags
}

################################################################################
# ECS Service
################################################################################

resource "aws_ecs_service" "redis" {
  name            = local.full_name
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.redis.arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = var.capacity_provider_name
    weight            = 1
    base              = 1
  }

  # Allow fast replacement without waiting for draining (no ALB, no target group)
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  ordered_placement_strategy {
    type  = "spread"
    field = "instanceId"
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = var.tags
}

