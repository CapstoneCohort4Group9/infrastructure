# terraform/modules/secrets/variables.tf
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
}

variable "enable_rotation" {
  description = "Enable automatic secret rotation"
  type        = bool
  default     = false
}

# terraform/modules/secrets/outputs.tf
output "api_secrets_arn" {
  description = "ARN of the API secrets"
  value       = aws_secretsmanager_secret.api_secrets.arn
}

output "api_secrets_name" {
  description = "Name of the API secrets"
  value       = aws_secretsmanager_secret.api_secrets.name
}

output "db_credentials_arn" {
  description = "ARN of the DB credentials secret"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "db_credentials_name" {
  description = "Name of the DB credentials secret"
  value       = aws_secretsmanager_secret.db_credentials.name
}
