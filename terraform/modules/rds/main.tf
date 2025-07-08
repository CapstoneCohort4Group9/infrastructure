# modules/rds/main.tf

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

# RDS Parameter Group for PostgreSQL with pgvector
resource "aws_db_parameter_group" "postgres_pgvector" {
  name   = "${var.identifier}-pgvector-params"
  family = "postgres17"

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements,pgvector"
  }

  tags = {
    Name        = "${var.identifier}-pgvector-params"
    Environment = var.environment
    Project     = var.project
  }
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "main" {
  identifier     = var.identifier
  engine         = "postgres"
  engine_version = "17.4" # Supports pgvector

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
  parameter_group_name   = aws_db_parameter_group.postgres_pgvector.name

  publicly_accessible = var.publicly_accessible

  # Backup and maintenance
  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window

  # Free tier settings
  skip_final_snapshot = true  # For development; change for production
  deletion_protection = false # For development; enable for production

  # Enable automated backups
  enabled_cloudwatch_logs_exports = ["postgresql"]

  # Performance insights (free tier includes 7 days)
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  tags = {
    Name        = var.identifier
    Environment = var.environment
    Project     = var.project
  }
}

# Create database and enable pgvector extension
resource "null_resource" "db_setup" {
  count = var.enable_pgvector ? 1 : 0

  depends_on = [aws_db_instance.main]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for RDS instance to be available..."
      sleep 60
      
      # Note: In production, use a proper method to enable pgvector
      # This is a placeholder - you'll need to connect to the database
      # and run: CREATE EXTENSION IF NOT EXISTS vector;
      echo "Please manually connect to the database and run: CREATE EXTENSION IF NOT EXISTS vector;"
    EOT
  }
}
