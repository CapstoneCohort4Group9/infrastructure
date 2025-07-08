# modules/rds/variables.tf
variable "identifier" {
  description = "The name of the RDS instance"
  type        = string
}

variable "db_name" {
  description = "The name of the database"
  type        = string
}

variable "username" {
  description = "The master username"
  type        = string
}

variable "password" {
  description = "The master password"
  type        = string
  sensitive   = true
}

variable "instance_class" {
  description = "The instance type of the RDS instance"
  type        = string
}

variable "allocated_storage" {
  description = "The allocated storage in gibibytes"
  type        = number
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for RDS"
  type        = string
}

variable "publicly_accessible" {
  description = "Bool to control if instance is publicly accessible"
  type        = bool
  default     = true
}

variable "backup_retention_period" {
  description = "The backup retention period"
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "The backup window"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "The maintenance window"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
}
