# Updated outputs.tf - Combines ECR, Secrets, and new infrastructure

# ECR Outputs
output "ecr_repository_urls" {
  description = "ECR repository URLs"
  value       = module.ecr.repository_urls
}

output "ecr_repository_arns" {
  description = "ECR repository ARNs"
  value       = module.ecr.repository_arns
}

# Secrets Outputs
output "secret_arns" {
  description = "ARNs of created secrets"
  value = {
    api_secrets    = module.secrets.api_secrets_arn
    db_credentials = module.secrets.db_credentials_arn
  }
  sensitive = true
}

# ALB Outputs
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.dns_name
}

output "alb_url" {
  description = "URL to access the frontend"
  value       = "http://${module.alb.dns_name}"
}

# RDS Outputs
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = module.rds.endpoint
  sensitive   = true
}

output "rds_address" {
  description = "RDS instance address"
  value       = module.rds.address
}

output "rds_port" {
  description = "RDS instance port"
  value       = module.rds.port
}

# ECS Outputs
output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs_cluster.cluster_name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = module.ecs_cluster.cluster_arn
}

# Service Discovery
output "service_discovery_namespace" {
  description = "Service discovery namespace"
  value       = aws_service_discovery_private_dns_namespace.main.name
}

# Service URLs
output "service_urls" {
  description = "Service URLs"
  value = {
    frontend_public   = "http://${module.alb.dns_name}"
    frontend_internal = "http://frontend-api.${aws_service_discovery_private_dns_namespace.main.name}:8075"
    langgraph         = "http://langgraph-api.${aws_service_discovery_private_dns_namespace.main.name}:8065"
    intent            = "http://intent-api.${aws_service_discovery_private_dns_namespace.main.name}:8085"
    sentiment         = "http://sentiment-api.${aws_service_discovery_private_dns_namespace.main.name}:8095"
    non_ai            = "http://non-ai-api.${aws_service_discovery_private_dns_namespace.main.name}:8003"
    rag               = "http://rag-api.${aws_service_discovery_private_dns_namespace.main.name}:8080"
  }
}

# Deployment Instructions
output "next_steps" {
  description = "Next steps after deployment"
  value       = <<-EOT
    
    Deployment Complete! Next steps:
    
    1. Enable pgvector in RDS:
       - Connect to: ${module.rds.endpoint}
       - Run: CREATE EXTENSION IF NOT EXISTS vector;
    
    2. Access your application:
       - Frontend URL: http://${module.alb.dns_name}
    
    3. Push Docker images to ECR:
       - Login: aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com
       - Tag and push each service image
    
    4. Monitor services:
       - ECS Console: https://console.aws.amazon.com/ecs/home?region=${var.aws_region}#/clusters/${module.ecs_cluster.cluster_name}
       - CloudWatch Logs: /ecs/<service-name>
  EOT
}
