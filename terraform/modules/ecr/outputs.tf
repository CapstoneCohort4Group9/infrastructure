output "repository_urls" {
  description = "Map of repository names to URLs"
  value = {
    for name, repo in aws_ecr_repository.this :
    name => repo.repository_url
  }
}

output "repository_arns" {
  description = "Map of repository names to ARNs"
  value = {
    for name, repo in aws_ecr_repository.this :
    name => repo.arn
  }
}

output "registry_id" {
  description = "The registry ID where the repositories were created"
  value       = values(aws_ecr_repository.this)[0].registry_id
}
