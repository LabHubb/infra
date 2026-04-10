################################
# ECS Service (reusable per service)
################################

locals {
  full_name = "${var.project_name}-${var.service.name}-${var.environment}"
}

# Needed to build the wildcard secret ARN for the task role policy
data "aws_caller_identity" "current" {}

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

      # Fixed host port = container port.
      # Dev:  nginx (host network) reaches the container via 127.0.0.1:<containerPort>
      #       because Docker publishes the port to 0.0.0.0:<hostPort> on the EC2 host.
      # Prod: ALB target group registers against containerPort; hostPort is used
      #       for the bridge-mode routing on the EC2 instance.
      # Rule: each service must use a unique containerPort across all services
      #       running on the same EC2 instance.
      portMappings = [
        {
          containerPort = var.service.container_port
          hostPort      = var.service.container_port
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
    }
  ])

  tags = var.tags
}

resource "aws_ecs_service" "this" {
  name                              = local.full_name
  cluster                           = var.cluster_id
  task_definition                   = aws_ecs_task_definition.this.arn
  desired_count                     = var.service.desired_count
  health_check_grace_period_seconds = var.target_group_arn != "" ? var.health_check_grace_period_seconds : 0

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
    ignore_changes = [desired_count]
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

# S3 access
data "aws_iam_policy_document" "s3_access" {
  count = length(var.s3_bucket_arns) > 0 ? 1 : 0
  statement {
    sid     = "S3ListBuckets"
    effect  = "Allow"
    actions = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = var.s3_bucket_arns
  }
  statement {
    sid    = "S3ObjectAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject", "s3:PutObject", "s3:DeleteObject",
      "s3:GetObjectVersion", "s3:ListMultipartUploadParts", "s3:AbortMultipartUpload",
    ]
    resources = [for arn in var.s3_bucket_arns : "${arn}/*"]
  }
}

resource "aws_iam_role_policy" "s3_access" {
  count  = length(var.s3_bucket_arns) > 0 ? 1 : 0
  name   = "${local.full_name}-s3-policy"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.s3_access[0].json
}

# Secrets Manager
data "aws_iam_policy_document" "task_secrets_access" {
  count = length(var.secrets_manager_secret_names) > 0 ? 1 : 0
  statement {
    sid    = "SecretsManagerRead"
    effect = "Allow"
    actions = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [
      for name in var.secrets_manager_secret_names :
      "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${name}*"
    ]
  }
}

resource "aws_iam_role_policy" "task_secrets_access" {
  count  = length(var.secrets_manager_secret_names) > 0 ? 1 : 0
  name   = "${local.full_name}-task-secrets-policy"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_secrets_access[0].json
}

# CloudWatch Logs
data "aws_iam_policy_document" "cloudwatch_logs" {
  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"]
    resources = ["arn:aws:logs:*:*:log-group:${var.log_group_name}:*"]
  }
}

resource "aws_iam_role_policy" "cloudwatch_logs" {
  name   = "${local.full_name}-cloudwatch-logs-policy"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.cloudwatch_logs.json
}
