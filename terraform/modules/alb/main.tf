################################
# Application Load Balancer
################################

resource "aws_lb" "this" {
  name               = "${var.name_prefix}-alb-001"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.enable_deletion_protection

  tags = var.tags
}

################################
# HTTP Listener – redirect to HTTPS
################################

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = var.tags
}

################################
# HTTPS Listener
################################

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }

  tags = var.tags
}

################################
# Target Groups + Listener Rules per service
################################

resource "aws_lb_target_group" "services" {
  for_each = var.services

  name        = "${var.name_prefix}-tg-${each.value.name}-001"
  port        = each.value.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = each.value.health_check_path
    port                = "traffic-port" # use the same port the container listens on
    protocol            = "HTTP"
    matcher             = lookup(each.value, "health_check_matcher", "200")
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = lookup(each.value, "health_check_interval", 30)
  }

  deregistration_delay = 30

  tags = var.tags
}

resource "aws_lb_listener_rule" "services" {
  for_each = var.services

  listener_arn = aws_lb_listener.https.arn
  priority     = each.value.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.services[each.key].arn
  }

  condition {
    path_pattern {
      values = [each.value.path_pattern]
    }
  }

  tags = var.tags
}
