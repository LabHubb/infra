################################
# Nginx as ECS Task – Dev reverse proxy
#
# Runs nginx as an ECS service on the SAME EC2 node as your app containers.
# Uses "host" network mode so nginx binds directly to port 80 on the EC2
# public IP – no separate EC2 instance or ALB needed.
#
# nginx config is passed via an ECS environment variable and written to disk
# by the container entrypoint. Each service gets a server block that proxies
# to localhost:<host_port> (dynamic port assigned by ECS bridge network).
#
# Architecture:
#   Internet → EC2 public IP:80 → nginx (host network, ECS task)
#                                      → proxy_pass localhost:<container_port>
#                                        → app ECS tasks (bridge network)
################################

locals {
  nginx_upstream_blocks = join("\n", [
    for svc in var.services :
    "upstream ${replace(svc.name, "-", "_")} { server 127.0.0.1:${svc.container_port}; }"
  ])

  nginx_server_blocks = join("\n", [
    for svc in var.services : <<-BLOCK
    server {
      listen 80;
      server_name ${svc.nginx_hostname};
      location ${svc.path_pattern == "/*" ? "/" : trimsuffix(svc.path_pattern, "*")} {
        proxy_pass         http://${replace(svc.name, "-", "_")};
        proxy_set_header   Host            $host;
        proxy_set_header   X-Real-IP       $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 60s;
      }
      location /health { return 200 'ok'; add_header Content-Type text/plain; }
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
  ${local.nginx_upstream_blocks}
  ${local.nginx_server_blocks}
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
      command     = ["CMD-SHELL", "curl -sf http://localhost/health || exit 1"]
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
    ignore_changes = [task_definition]
  }
}
