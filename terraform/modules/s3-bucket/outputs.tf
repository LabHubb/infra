output "bucket_names" {
  description = "Map of bucket key → bucket name"
  value       = { for k, b in aws_s3_bucket.this : k => b.id }
}

output "bucket_arns" {
  description = "Map of bucket key → bucket ARN"
  value       = { for k, b in aws_s3_bucket.this : k => b.arn }
}

output "bucket_regional_domain_names" {
  description = "Map of bucket key → regional domain name"
  value       = { for k, b in aws_s3_bucket.this : k => b.bucket_regional_domain_name }
}

output "website_endpoints" {
  description = "Map of bucket key → website endpoint (only for website-enabled buckets)"
  value = {
    for k, w in aws_s3_bucket_website_configuration.this : k => w.website_endpoint
  }
}
