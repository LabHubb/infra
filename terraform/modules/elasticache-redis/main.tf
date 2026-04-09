################################
# ElastiCache Redis
################################

resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name_prefix}-redis-${var.redis_name}-subnet-group-001"
  subnet_ids = var.private_subnet_ids

  tags = var.tags
}

resource "aws_elasticache_parameter_group" "this" {
  name   = "${var.name_prefix}-redis-${var.redis_name}-pg-001"
  family = "redis7"

  tags = var.tags
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id = "${var.name_prefix}-redis-${var.redis_name}-001"
  description          = "Redis replication group for ${var.name_prefix}-redis-${var.redis_name}-001"

  node_type            = var.node_type
  num_cache_clusters   = var.num_cache_clusters
  port                 = 6379
  parameter_group_name = aws_elasticache_parameter_group.this.name
  subnet_group_name    = aws_elasticache_subnet_group.this.name
  security_group_ids   = [var.redis_sg_id]

  engine_version             = var.engine_version
  at_rest_encryption_enabled = true
  transit_encryption_enabled = var.transit_encryption_enabled
  transit_encryption_mode    = var.transit_encryption_enabled ? var.transit_encryption_mode : null
  auth_token                 = var.transit_encryption_enabled ? var.auth_token : null
  apply_immediately          = true

  automatic_failover_enabled = var.num_cache_clusters > 1 ? true : false
  multi_az_enabled           = var.num_cache_clusters > 1 ? true : false

  snapshot_retention_limit = var.snapshot_retention_limit
  snapshot_window          = "05:00-06:00"
  maintenance_window       = "Mon:06:00-Mon:07:00"

  tags = var.tags
}
