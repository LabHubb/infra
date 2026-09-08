locals {
  # An empty overrides list makes the ASG fall back to the launch template's
  # instance_type, so only emit overrides when extra types are configured.
  spot_override_types = length(var.spot_instance_types) > 0 ? distinct(concat([var.instance_type], var.spot_instance_types)) : []
}

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
    auto_scaling_group_arn = aws_autoscaling_group.this.arn

    # DISABLED: managed termination protection requires protect_from_scale_in = true
    # on the ASG, which would prevent scaling to 0 (used by the stop scheduler).
    # ECS graceful draining is still handled by the ECS agent on the instance itself.
    managed_termination_protection = "DISABLED"

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

  # Amazon Linux 2023 ECS-optimized AMI user_data notes:
  # - AL2023 uses dnf (not yum); the ecs-init package is pre-installed on the ECS-optimized AMI.
  # - /etc/ecs/ecs.config is the same config file path as AL2.
  # - ECS_ENABLE_SPOT_INSTANCE_DRAINING=true gracefully drains tasks before a Spot interruption.
  user_data = base64encode(<<-EOF
    #!/bin/bash
    cat <<'ECSCONFIG' >> /etc/ecs/ecs.config
    ECS_CLUSTER=${aws_ecs_cluster.this.name}
    ECS_ENABLE_CONTAINER_METADATA=true
    ECS_ENABLE_SPOT_INSTANCE_DRAINING=true
    ECS_LOGLEVEL=warn
    ECSCONFIG
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

  # Do NOT set protect_from_scale_in = true at the ASG level.
  # ECS Capacity Provider managed_termination_protection = "ENABLED" handles
  # graceful task draining by toggling instance-level scale-in protection
  # dynamically. ASG-level protection would block the scheduler from scaling to 0.
  protect_from_scale_in = false

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
        on_demand_base_capacity                  = var.on_demand_base_capacity
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

        dynamic "override" {
          for_each = local.spot_override_types
          content {
            instance_type = override.value
          }
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
