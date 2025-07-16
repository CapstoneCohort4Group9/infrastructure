# modules/alb/outputs.tf
output "alb_arn" {
  description = "ARN of the load balancer"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the load balancer"
  value       = aws_lb.main.zone_id
}

output "target_group_arn" {
  description = "ARN of the frontend target group"
  value       = aws_lb_target_group.frontend.arn
}

output "listener_arn" {
  description = "ARN of the HTTP listener"
  value       = aws_lb_listener.http.arn
}

output "dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "security_group_id" {
  description = "Security group ID of the ALB"
  value       = length(var.security_group_ids) > 0 ? var.security_group_ids[0] : ""
}

# Conditional outputs for internal services target groups
output "langgraph_target_group_arn" {
  description = "ARN of the langgraph target group"
  value       = var.expose_internal_services ? aws_lb_target_group.langgraph[0].arn : ""
}

output "intent_target_group_arn" {
  description = "ARN of the intent target group"
  value       = var.expose_internal_services ? aws_lb_target_group.intent[0].arn : ""
}

output "sentiment_target_group_arn" {
  description = "ARN of the sentiment target group"
  value       = var.expose_internal_services ? aws_lb_target_group.sentiment[0].arn : ""
}

output "non_ai_target_group_arn" {
  description = "ARN of the non-ai target group"
  value       = var.expose_internal_services ? aws_lb_target_group.non_ai[0].arn : ""
}

output "rag_target_group_arn" {
  description = "ARN of the rag target group"
  value       = var.expose_internal_services ? aws_lb_target_group.rag[0].arn : ""
}
