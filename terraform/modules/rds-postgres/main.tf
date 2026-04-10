################################
# RDS PostgreSQL
################################

resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-rds-${var.postgres_name}-subnet-group-001"
  subnet_ids = var.private_subnet_ids

  tags = var.tags
}

resource "aws_db_parameter_group" "this" {
  name   = "${var.name_prefix}-rds-${var.postgres_name}-pg-001"
  family = "postgres16"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  # Enable pg_cron extension – must be in shared_preload_libraries before CREATE EXTENSION
  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_cron"
    apply_method = "pending-reboot"
  }

  # pg_cron maintenance database – must match the application database name
  parameter {
    name         = "cron.database_name"
    value        = var.db_name
    apply_method = "pending-reboot"
  }

  tags = var.tags
}

resource "aws_db_instance" "this" {
  identifier = "${var.name_prefix}-rds-${var.postgres_name}-001"

  engine                = "postgres"
  engine_version        = var.engine_version
  instance_class        = var.instance_class
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.postgres_sg_id]
  parameter_group_name   = aws_db_parameter_group.this.name

  backup_retention_period = var.backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  multi_az                  = var.multi_az
  publicly_accessible       = false
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name_prefix}-rds-${var.postgres_name}-final-snapshot-001"

  tags = var.tags
}
