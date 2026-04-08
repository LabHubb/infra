################################
# S3 Buckets (multi-bucket)
################################

locals {
  # If 'name' is set, use it as-is; otherwise fall back to name_prefix-suffix.
  bucket_names = {
    for k, b in var.buckets : k => b.name != null ? b.name : "${var.name_prefix}-${b.suffix}"
  }
}

# ── Core bucket ──────────────────────────────────────────────────────────────
resource "aws_s3_bucket" "this" {
  for_each = var.buckets

  bucket = local.bucket_names[each.key]
  tags   = merge(var.tags, { Name = local.bucket_names[each.key] })
}

# ── Versioning ───────────────────────────────────────────────────────────────
resource "aws_s3_bucket_versioning" "this" {
  for_each = var.buckets

  bucket = aws_s3_bucket.this[each.key].id
  versioning_configuration {
    status = each.value.versioning_enabled ? "Enabled" : "Suspended"
  }
}

# ── Encryption ───────────────────────────────────────────────────────────────
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = var.buckets

  bucket = aws_s3_bucket.this[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = each.value.sse_algorithm
      kms_master_key_id = each.value.sse_algorithm == "aws:kms" ? each.value.kms_master_key_id : null
    }
  }
}

# ── Public access block ──────────────────────────────────────────────────────
resource "aws_s3_bucket_public_access_block" "this" {
  for_each = var.buckets

  bucket = aws_s3_bucket.this[each.key].id

  block_public_acls       = each.value.access == "private"
  block_public_policy     = each.value.access == "private"
  ignore_public_acls      = each.value.access == "private"
  restrict_public_buckets = each.value.access == "private"
}

# ── Bucket ownership controls (required when access != private) ──────────────
resource "aws_s3_bucket_ownership_controls" "this" {
  for_each = { for k, b in var.buckets : k => b if b.access != "private" }

  bucket = aws_s3_bucket.this[each.key].id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# ── Public-read bucket policy ────────────────────────────────────────────────
resource "aws_s3_bucket_policy" "public_read" {
  for_each = { for k, b in var.buckets : k => b if b.access == "public-read" }

  bucket = aws_s3_bucket.this[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.this[each.key].arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.this]
}

# ── Lifecycle rules ──────────────────────────────────────────────────────────
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  for_each = var.buckets

  bucket = aws_s3_bucket.this[each.key].id

  rule {
    id     = "transition-old-versions"
    status = "Enabled"

    filter {
      prefix = ""
    }

    dynamic "noncurrent_version_transition" {
      for_each = each.value.versioning_enabled ? [1] : []
      content {
        noncurrent_days = each.value.noncurrent_version_transition_ia_days
        storage_class   = "STANDARD_IA"
      }
    }

    dynamic "noncurrent_version_transition" {
      for_each = each.value.versioning_enabled ? [1] : []
      content {
        noncurrent_days = each.value.noncurrent_version_transition_glacier_days
        storage_class   = "GLACIER"
      }
    }

    dynamic "noncurrent_version_expiration" {
      for_each = each.value.versioning_enabled ? [1] : []
      content {
        noncurrent_days = each.value.noncurrent_version_expiration_days
      }
    }
  }

  rule {
    id     = "abort-incomplete-multipart"
    status = "Enabled"

    filter {
      prefix = ""
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = each.value.abort_incomplete_multipart_days
    }
  }
}

# ── CORS ─────────────────────────────────────────────────────────────────────
resource "aws_s3_bucket_cors_configuration" "this" {
  for_each = { for k, b in var.buckets : k => b if length(b.cors_allowed_origins) > 0 }

  bucket = aws_s3_bucket.this[each.key].id

  cors_rule {
    allowed_headers = each.value.cors_allowed_headers
    allowed_methods = each.value.cors_allowed_methods
    allowed_origins = each.value.cors_allowed_origins
    expose_headers  = each.value.cors_expose_headers
    max_age_seconds = each.value.cors_max_age_seconds
  }
}

# ── Static website ────────────────────────────────────────────────────────────
resource "aws_s3_bucket_website_configuration" "this" {
  for_each = { for k, b in var.buckets : k => b if b.website_enabled }

  bucket = aws_s3_bucket.this[each.key].id

  index_document {
    suffix = each.value.website_index_page
  }

  error_document {
    key = each.value.website_error_page
  }
}
