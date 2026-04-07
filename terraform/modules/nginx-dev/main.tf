################################
# Nginx on EC2 – Dev load balancer
# Replaces ALB in dev environment.
# Each EC2 node gets a public IP; nginx proxies to ECS containers on localhost.
################################

locals {
  nginx_upstream_blocks = join("\n", [
    for svc in var.services : <<-BLOCK
    upstream ${replace(svc.name, "-", "_")} {
      server 127.0.0.1:${svc.container_port};
    }
    BLOCK
  ])

  nginx_server_blocks = join("\n", [
    for svc in var.services : <<-BLOCK
    server {
      listen 80;
      server_name ${svc.nginx_hostname};

      location ${svc.path_pattern == "/*" ? "/" : trimsuffix(svc.path_pattern, "*")} {
        proxy_pass         http://${replace(svc.name, "-", "_")};
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_read_timeout 60s;
      }

      location /health {
        return 200 'ok';
        add_header Content-Type text/plain;
      }
    }
    BLOCK
  ])

  nginx_conf = <<-CONF
    user nginx;
    worker_processes auto;
    error_log /var/log/nginx/error.log warn;
    pid /var/run/nginx.pid;

    events {
      worker_connections 1024;
    }

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

################################
# Security Group for nginx EC2
################################

resource "aws_security_group" "nginx" {
  name        = "${var.name_prefix}-nginx-sg"
  description = "Nginx dev LB – HTTP/HTTPS from internet, SSH from allowed CIDRs"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS"
  }

  dynamic "ingress" {
    for_each = length(var.ssh_allowed_cidrs) > 0 ? [1] : []
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.ssh_allowed_cidrs
      description = "SSH"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-nginx-sg" })
}

################################
# Launch Template for nginx EC2
################################

resource "aws_launch_template" "nginx" {
  name_prefix   = "${var.name_prefix}-nginx-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  iam_instance_profile {
    name = var.ecs_instance_profile_name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.nginx.id, var.ecs_sg_id]
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e

    # Register to ECS cluster
    echo ECS_CLUSTER=${var.ecs_cluster_name} >> /etc/ecs/ecs.config
    echo ECS_ENABLE_CONTAINER_METADATA=true >> /etc/ecs/ecs.config

    # Install nginx
    amazon-linux-extras enable nginx1 || true
    yum install -y nginx

    # Write nginx config
    cat > /etc/nginx/nginx.conf << 'NGINXCONF'
    ${local.nginx_conf}
    NGINXCONF

    systemctl enable nginx
    systemctl start nginx
  EOF
  )

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

################################
# Auto Scaling Group (public subnets)
################################

resource "aws_autoscaling_group" "nginx" {
  name                = "${var.name_prefix}-nginx-asg"
  vpc_zone_identifier = var.public_subnet_ids
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  desired_capacity    = var.asg_desired_capacity

  protect_from_scale_in = true

  launch_template {
    id      = aws_launch_template.nginx.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-nginx-node"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}
