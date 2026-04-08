################################
# ECS Service (reusable per service)
################################

locals {
  full_name = "${var.project_name}-${var.service.name}-${var.environment}"
}

resource "aws_ecs_task_definition" "this" {
  family                   = local.full_name
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = var.service.cpu
  memory                   = var.service.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = var.service.name
      image     = var.service.image
      cpu       = var.service.cpu
      memory    = var.service.memory
      essential = true

      portMappings = [
        {
          containerPort = var.service.container_port
          hostPort      = 0
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.log_group_name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      environment = var.service.environment_variables

      # Secrets pulled from AWS Secrets Manager at container start
      secrets = [
        for k, arn in var.secret_arns : {
          name      = k
          valueFrom = arn
        }
      ]
    }
  ])

  tags = var.tags
}

resource "aws_ecs_service" "this" {
  name                              = local.full_name
  cluster                           = var.cluster_id
  task_definition                   = aws_ecs_task_definition.this.arn
  desired_count                     = var.service.desired_count
  health_check_grace_period_seconds = var.target_group_arn != "" ? 30 : 0

  capacity_provider_strategy {
    capacity_provider = var.capacity_provider_name
    weight            = 1
    base              = 1
  }

  # Only attach to ALB target group when one is provided (prod). Dev has no ALB.
  dynamic "load_balancer" {
    for_each = var.target_group_arn != "" ? [1] : []
    content {
      target_group_arn = var.target_group_arn
      container_name   = var.service.name
      container_port   = var.service.container_port
    }
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }

  lifecycle {
    ignore_changes = [desired_count, task_definition]
  }

  tags = var.tags
}

################################
# IAM – Task Execution Role
################################

data "aws_iam_policy_document" "task_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${local.full_name}-exec-role"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Grant execution role access to read Secrets Manager secrets
data "aws_iam_policy_document" "secrets_access" {
  count = length(var.secret_arns) > 0 ? 1 : 0

  statement {
    sid       = "AllowSecretsManagerRead"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = values(var.secret_arns)
  }
}

resource "aws_iam_role_policy" "secrets_access" {
  count  = length(var.secret_arns) > 0 ? 1 : 0
  name   = "${local.full_name}-secrets-policy"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.secrets_access[0].json
}

################################
# IAM – Task Role
################################

resource "aws_iam_role" "task" {
  name               = "${local.full_name}-task-role"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "task_custom" {
  count  = length(var.task_policy_json) > 0 ? 1 : 0
  name   = "${local.full_name}-task-policy"
  role   = aws_iam_role.task.id
  policy = var.task_policy_json
}
