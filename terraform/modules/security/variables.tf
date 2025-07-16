# modules/security/variables.tf
variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
}

variable "alb_security_group_id" {
  description = "ALB security group ID (if exists)"
  type        = string
  default     = ""
}

variable "service_ports" {
  description = "List of service ports to allow"
  type        = list(number)
  default     = [8003, 8065, 8075, 8080, 8085, 8095]
}

variable "expose_internal_services" {
  description = "Temporarily expose internal services via ALB"
  type        = bool
  default     = false
}