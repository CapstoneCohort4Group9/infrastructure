# terraform/modules/secrets/main.tf

# API Secrets
resource "aws_secretsmanager_secret" "api_secrets" {
  name                    = "api_secrets"
  description             = "Stores API key and secret"
  recovery_window_in_days = 0 # Can be 0 for immediate deletion

  tags = {
    Name        = "api_secrets"
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = var.project
  }
}

# API Secret Version with actual values
resource "aws_secretsmanager_secret_version" "api_secrets" {
  secret_id = aws_secretsmanager_secret.api_secrets.id
  secret_string = jsonencode({
    api_key    = var.api_key
    api_secret = var.api_secret
  })
}

# DB Credentials
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "db_credentials"
  description             = "Holds the database username and password"
  recovery_window_in_days = 0 # Can be 0 for immediate deletion

  tags = {
    Name        = "db_credentials"
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = var.project
  }
}

# DB Secret Version with actual values
resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    db_user = var.db_user
    db_pass = var.db_pass
  })
}

# Data sources to retrieve the secrets (for use by other resources)
data "aws_secretsmanager_secret_version" "api_secrets" {
  secret_id  = aws_secretsmanager_secret.api_secrets.id
  depends_on = [aws_secretsmanager_secret_version.api_secrets]
}

data "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id  = aws_secretsmanager_secret.db_credentials.id
  depends_on = [aws_secretsmanager_secret_version.db_credentials]
}

