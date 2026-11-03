################################
# AWS SES Domain Identity & DKIM
# DNS is managed externally on Cloudflare, so this module creates the SES domain
# identity + Easy DKIM tokens and outputs the exact CNAME/TXT records to add in
# Cloudflare DNS (with Proxy status = DNS only / grey cloud).
################################

resource "aws_ses_domain_identity" "this" {
  domain = var.domain
}

resource "aws_ses_domain_dkim" "this" {
  domain = aws_ses_domain_identity.this.domain
}
