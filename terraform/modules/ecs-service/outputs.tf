# modules/ecs-service/outputs.tf
output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.service.name
}

output "service_id" {
  description = "ARN of the ECS service"
  value       = aws_ecs_service.service.id
}

output "task_definition_arn" {
  description = "ARN of the task definition"
  value       = aws_ecs_task_definition.service.arn
}

output "service_discovery_name" {
  description = "Service discovery name"
  value       = var.enable_service_discovery ? aws_service_discovery_service.service[0].name : ""
}
