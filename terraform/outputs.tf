output "ecr_repository_urls" {
  description = "ECR repository URLs"
  value       = module.ecr.repository_urls
}

output "ecr_repository_arns" {
  description = "ECR repository ARNs"
  value       = module.ecr.repository_arns
}

output "secret_arns" {
  description = "ARNs of created secrets"
  value = {
    api_secrets    = module.secrets.api_secrets_arn
    db_credentials = module.secrets.db_credentials_arn
  }
  sensitive = true
}

