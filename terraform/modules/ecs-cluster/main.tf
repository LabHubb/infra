################################
# ECS Cluster (EC2 launch type)
################################

resource "aws_ecs_cluster" "this" {
  name = "${var.name_prefix}-ecs-cluster-001"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = var.tags
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = [aws_ecs_capacity_provider.this.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.this.name
    weight            = 1
    base              = 1
  }
}

resource "aws_ecs_capacity_provider" "this" {
  name = "cp-${var.name_prefix}-001"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.this.arn
    managed_termination_protection = "ENABLED"

    managed_scaling {
      maximum_scaling_step_size = 5
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 80
    }
  }

  tags = var.tags
}

################################
# Launch Template
################################

resource "aws_launch_template" "this" {
  name_prefix   = "${var.name_prefix}-ecs-lt-001-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance.name
  }

  network_interfaces {
    associate_public_ip_address = var.associate_public_ip_address
    security_groups             = [var.ecs_sg_id]
  }

  # NOTE: Do NOT set instance_market_options (spot) here.
  # Spot is controlled entirely by mixed_instances_policy in the ASG.
  # Setting spot in the launch template AND mixed_instances_policy causes:
  # "Incompatible launch template" error from AWS Auto Scaling.

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.this.name} >> /etc/ecs/ecs.config
    echo ECS_ENABLE_CONTAINER_METADATA=true >> /etc/ecs/ecs.config
  EOF
  )

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

################################
# Auto Scaling Group
################################

resource "aws_autoscaling_group" "this" {
  name                = "${var.name_prefix}-ecs-asg-001"
  vpc_zone_identifier = var.subnet_ids
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  desired_capacity    = var.asg_desired_capacity

  protect_from_scale_in = true

  # On-demand: use a simple launch_template block.
  # Spot: use mixed_instances_policy which embeds its own launch_template spec.
  # Only one of the two can be set at a time.
  dynamic "launch_template" {
    for_each = var.use_spot ? [] : [1]
    content {
      id      = aws_launch_template.this.id
      version = "$Latest"
    }
  }

  dynamic "mixed_instances_policy" {
    for_each = var.use_spot ? [1] : []
    content {
      instances_distribution {
        on_demand_base_capacity                  = 0
        on_demand_percentage_above_base_capacity = 0
        spot_allocation_strategy                 = "capacity-optimized"
        # "" means AWS caps at on-demand price; explicit value sets a hard max bid
        spot_max_price = var.spot_max_price != "" ? var.spot_max_price : null
      }
      launch_template {
        launch_template_specification {
          launch_template_id = aws_launch_template.this.id
          version            = "$Latest"
        }
      }
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-ecs-node-001"
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

################################
# IAM for ECS EC2 instances
################################

data "aws_iam_policy_document" "ecs_instance_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_instance" {
  name               = "${var.name_prefix}-ecs-instance-role-001"
  assume_role_policy = data.aws_iam_policy_document.ecs_instance_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "ecs_instance" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ssm_instance" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ecs_instance" {
  name = "${var.name_prefix}-ecs-instance-profile-001"
  role = aws_iam_role.ecs_instance.name
  tags = var.tags
}
