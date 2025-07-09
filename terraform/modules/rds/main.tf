# modules/rds/main.tf

data "aws_vpc" "selected" {
  id = var.vpc_id
}

# Add a local validation
locals {
  validate_dns = var.publicly_accessible && (!data.aws_vpc.selected.enable_dns_support || !data.aws_vpc.selected.enable_dns_hostnames) ? file("ERROR: VPC DNS settings must be enabled for public RDS access") : null
}

# RDS Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.identifier}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name        = "${var.identifier}-subnet-group"
    Environment = var.environment
    Project     = var.project
  }
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "main" {
  identifier     = var.identifier
  engine         = "postgres"
  engine_version = "17.4"

  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  storage_type      = "gp2"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.username
  password = var.password
  port     = 5432

  vpc_security_group_ids = [var.security_group_id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  # parameter_group_name is omitted to use default.postgres17
  # Alternatively, explicitly set: parameter_group_name = "default.postgres17"

  publicly_accessible = var.publicly_accessible

  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window

  skip_final_snapshot = true
  deletion_protection = false

  enabled_cloudwatch_logs_exports = ["postgresql"]

  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  apply_immediately = false # Use maintenance window for changes

  # Lifecycle block to ignore changes that might be made outside of Terraform
  lifecycle {
    ignore_changes = [
      # Ignore changes to engine version (in case of minor version updates)
      engine_version,
      # Ignore parameter group changes (for pgvector extension setup)
      parameter_group_name,
      # Ignore password changes (if changed manually)
      password,
      # Ignore backup window changes (if adjusted for maintenance)
      backup_window,
      maintenance_window,
      # Ignore storage changes (if manually increased)
      allocated_storage,
      # Ignore instance class changes (if manually scaled)
      instance_class,
      # Ignore any manual configuration changes
      apply_immediately,
      # Ignore CloudWatch logs configuration changes
      enabled_cloudwatch_logs_exports,
      # Ignore Performance Insights changes
      performance_insights_enabled,
      performance_insights_retention_period
    ]
  }

  tags = {
    Name        = var.identifier
    Environment = var.environment
    Project     = var.project
  }
}
