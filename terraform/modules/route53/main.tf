################################
# Route53 DNS Records
# Supports both ALB alias records (prod) and direct IP A records (dev/nginx)
################################

data "aws_route53_zone" "this" {
  name         = var.hosted_zone_name
  private_zone = false
}

# ALB alias records (prod – when alb_dns_name is provided)
resource "aws_route53_record" "alias" {
  for_each = var.alb_dns_name != "" ? var.service_dns_records : {}

  zone_id = data.aws_route53_zone.this.zone_id
  name    = "${each.value.subdomain}.${var.hosted_zone_name}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

# Direct IP A records (dev – when ip_addresses list is provided)
resource "aws_route53_record" "ip" {
  for_each = var.alb_dns_name == "" ? var.service_dns_records : {}

  zone_id = data.aws_route53_zone.this.zone_id
  name    = "${each.value.subdomain}.${var.hosted_zone_name}"
  type    = "A"
  ttl     = 60
  records = var.ip_addresses
}
