output "record_fqdns" {
  description = "Map of service key to fully qualified domain name"
  value = merge(
    { for k, v in aws_route53_record.alias : k => v.fqdn },
    { for k, v in aws_route53_record.ip : k => v.fqdn }
  )
}
