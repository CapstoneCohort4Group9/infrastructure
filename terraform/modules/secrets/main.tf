# terraform/modules/secrets/main.tf

# API Secrets
resource "aws_secretsmanager_secret" "api_secrets" {
  name                    = "api_secrets"
  description            = "Stores API key and secret"
  recovery_window_in_days = 0  # Can be 0 for immediate deletion

  # Rotation configuration (optional)
  # rotation_rules {
  #   automatically_after_days = 90
  # }

  tags = {
    Name        = "api_secrets"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# DB Credentials
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "db_credentials"
  description            = "Holds the database username and password"
  recovery_window_in_days = 0 # Can be 0 for immediate deletion

  tags = {
    Name        = "db_credentials"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Note: We're NOT creating secret versions here - that's handled by the PowerShell script
# This separation keeps sensitive values out of Terraform state

# Optional: Create placeholder versions if you want Terraform to manage everything
# resource "aws_secretsmanager_secret_version" "api_secrets" {
#   secret_id     = aws_secretsmanager_secret.api_secrets.id
#   secret_string = jsonencode({
#     api_key    = "PLACEHOLDER"
#     api_secret = "PLACEHOLDER"
#   })
#   
#   lifecycle {
#     ignore_changes = [secret_string]  # Ignore changes made outside Terraform
#   }
# }