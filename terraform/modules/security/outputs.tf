# modules/security/outputs.tf
output "alb_security_group_id" {
  description = "Security group ID for ALB"
  value       = aws_security_group.alb.id
}

output "ecs_service_security_group_id" {
  description = "Security group ID for ECS services"
  value       = aws_security_group.ecs_service.id
}

output "rds_security_group_id" {
  description = "Security group ID for RDS"
  value       = aws_security_group.rds.id
}