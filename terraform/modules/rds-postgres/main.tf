################################
# RDS PostgreSQL
################################

resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-${var.postgres_name}-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = var.tags
}

resource "aws_db_parameter_group" "this" {
  name   = "${var.name_prefix}-${var.postgres_name}-pg"
  family = "postgres16"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  tags = var.tags
}

resource "aws_db_instance" "this" {
  identifier = "${var.name_prefix}-${var.postgres_name}"

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
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name_prefix}-${var.postgres_name}-final"

  tags = var.tags
}
