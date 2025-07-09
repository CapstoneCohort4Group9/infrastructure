# terraform/modules/secrets/outputs.tf
output "api_secrets_arn" {
  description = "ARN of the API secrets"
  value       = aws_secretsmanager_secret.api_secrets.arn
}

output "api_secrets_name" {
  description = "Name of the API secrets"
  value       = aws_secretsmanager_secret.api_secrets.name
}

output "api_secrets_id" {
  description = "ID of the API secrets"
  value       = aws_secretsmanager_secret.api_secrets.id
}

output "db_credentials_arn" {
  description = "ARN of the DB credentials secret"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "db_credentials_name" {
  description = "Name of the DB credentials secret"
  value       = aws_secretsmanager_secret.db_credentials.name
}

output "db_credentials_id" {
  description = "ID of the DB credentials secret"
  value       = aws_secretsmanager_secret.db_credentials.id
}
# Parsed secret values for use by other resources
output "api_secrets_parsed" {
  description = "Parsed API secrets (use carefully - sensitive)"
  value       = jsondecode(data.aws_secretsmanager_secret_version.api_secrets.secret_string)
  sensitive   = true
}

output "db_credentials_parsed" {
  description = "Parsed DB credentials (use carefully - sensitive)"
  value       = jsondecode(data.aws_secretsmanager_secret_version.db_credentials.secret_string)
  sensitive   = true
}
