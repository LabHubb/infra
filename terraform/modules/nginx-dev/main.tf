################################
# Nginx as ECS Task – Dev reverse proxy
#
# Architecture:
#   nginx task  → network_mode = "host"   → binds port 80 directly on the EC2 host
#   app tasks   → network_mode = "bridge" → Docker publishes hostPort on 0.0.0.0:<port>
#
# Why 127.0.0.1 works:
#   Docker bridge mode with a fixed hostPort binds the container port to
#   0.0.0.0:<hostPort> on the EC2 host network interface.
#   Nginx runs in host network mode, so it IS on the EC2 host – it can reach
#   any port published by Docker via 127.0.0.1:<hostPort>.
#
#   nginx (host net) → proxy_pass 127.0.0.1:8080
#                           ↓
#   Docker NAT rule: 0.0.0.0:8080 → be-app container:8080  ✓
#
# Rule: each service must use a unique container_port in terraform.tfvars.
#   be-app      container_port = 8080
#   fe-admin    container_port = 3001
#   fe-customer container_port = 3002
################################

locals {
  nginx_location_blocks = join("\n", [
    for svc in var.services :
    <<-BLOCK
    location ${svc.path_pattern == "/*" ? "/" : trimsuffix(svc.path_pattern, "/*")} {
      proxy_pass         http://127.0.0.1:${svc.container_port};
      proxy_set_header   Host            $host;
      proxy_set_header   X-Real-IP       $remote_addr;
      proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_read_timeout 60s;
    }
    BLOCK
  ])

  nginx_conf = <<-CONF
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;
events { worker_connections 1024; }
http {
  include       /etc/nginx/mime.types;
  default_type  application/octet-stream;
  sendfile      on;
  keepalive_timeout 65;
  server {
    listen 80 default_server;
    server_name _;
${local.nginx_location_blocks}
    location /health       { return 200 'ok'; add_header Content-Type text/plain; }
    location /nginx-health { return 200 'ok'; add_header Content-Type text/plain; }
  }
}
CONF
}

################################################################################
# CloudWatch Log Group for nginx
################################################################################

resource "aws_cloudwatch_log_group" "nginx" {
  name              = "/aws/ecs/${var.project_name}/${var.environment}/nginx"
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
  name               = "${var.name_prefix}-nginx-exec-role"
  assume_role_policy = data.aws_iam_policy_document.exec_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "exec" {
  role       = aws_iam_role.exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

################################################################################
# ECS Task Definition – nginx (host network, port 80 on EC2)
################################################################################

resource "aws_ecs_task_definition" "nginx" {
  family                   = "${var.project_name}-nginx-${var.environment}"
  network_mode             = "host"   # binds directly to EC2 host ports 80/443
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.exec.arn

  container_definitions = jsonencode([{
    name              = "nginx"
    image             = "nginx:alpine"
    essential         = true
    cpu               = 128
    memory            = 256

    # host network mode – no portMappings needed, nginx binds to host port 80
    portMappings = []

    # Write nginx config via entrypoint
    entryPoint = ["/bin/sh", "-c"]
    command    = [
      "echo \"$NGINX_CONF\" > /etc/nginx/nginx.conf && nginx -t && exec nginx -g 'daemon off;'"
    ]

    environment = [
      {
        name  = "NGINX_CONF"
        value = local.nginx_conf
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.nginx.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "nginx"
      }
    }

    # Needs to start before app containers are ready, but health check keeps it stable
    healthCheck = {
      command     = ["CMD-SHELL", "curl -sf http://localhost/nginx-health || exit 1"]
      interval    = 15
      timeout     = 5
      retries     = 3
      startPeriod = 10
    }
  }])

  tags = var.tags
}

################################################################################
# ECS Service – nginx (1 replica, runs on every EC2 node via daemon scheduling)
################################################################################

resource "aws_ecs_service" "nginx" {
  name            = "${var.project_name}-nginx-${var.environment}"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.nginx.arn
  desired_count   = 1

  # Use the same capacity provider as the rest of the cluster
  capacity_provider_strategy {
    capacity_provider = var.capacity_provider_name
    weight            = 1
    base              = 1
  }

  # Restart nginx when config changes (new task definition revision)
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  # Allow rolling restarts without waiting for ALB draining (no ALB in dev)
  ordered_placement_strategy {
    type  = "spread"
    field = "instanceId"
  }

  tags = var.tags

  lifecycle {
    ignore_changes = []
  }
}
