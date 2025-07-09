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

variable "api_key" {
  description = "API key for the application"
  type        = string
  sensitive   = true
  default     = "my-secret-key"
}

variable "api_secret" {
  description = "API secret for the application"
  type        = string
  sensitive   = true
  default     = "Capst0neo3@2024"
}

variable "db_user" {
  description = "Database username"
  type        = string
  sensitive   = true
  default     = "hopjetair"
}

variable "db_pass" {
  description = "Database password"
  type        = string
  sensitive   = true
  default     = "SecurePass123!"
}


