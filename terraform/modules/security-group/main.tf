################################
# Generic Security Group module
# Call once per logical group (alb, ecs, redis, postgres)
################################

resource "aws_security_group" "this" {
  name        = "${var.name_prefix}-${var.sg_name}-sg"
  description = var.description
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name_prefix}-${var.sg_name}-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = { for idx, rule in var.ingress_rules : idx => rule }

  security_group_id = aws_security_group.this.id

  from_port   = each.value.from_port
  to_port     = each.value.to_port
  ip_protocol = each.value.protocol

  cidr_ipv4                    = lookup(each.value, "cidr_ipv4", null)
  referenced_security_group_id = lookup(each.value, "source_sg_id", null)
  description                  = lookup(each.value, "description", null)
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow all outbound"
}
