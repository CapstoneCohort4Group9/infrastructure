# Updated variables.tf - Everything in us-east-1

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1" # Changed from ap-south-1
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "hopjetair"
}

variable "api_key" {
  description = "API key for the application"
  type        = string
  sensitive   = true
}

variable "api_secret" {
  description = "API secret for the application"
  type        = string
  sensitive   = true
}

variable "db_user" {
  description = "Database username"
  type        = string
  sensitive   = true
}

variable "db_pass" {
  description = "Database password"
  type        = string
  sensitive   = true
}

# Existing VPC resources from your Bedrock setup in us-east-1
variable "existing_vpc_id" {
  description = "Existing VPC ID"
  type        = string
  default     = "vpc-01233dc74a0ff1a87" #"vpc-063dd9b87946bb995"
}

variable "existing_public_subnet_ids" {
  description = "Existing public subnet IDs"
  type        = list(string)
  default = [
    "subnet-09d35aa6c4fdefbc6", # us-east-1a   "subnet-0ccc1961403c1960b", #
    "subnet-04710615fd2a3cdb5", # us-east-1b  "subnet-0a1a77e97cd45bcae", #
    "subnet-0f8aa8bffb3f0d924", # us-east-1c  "subnet-0d44d04770610077e", #
    "subnet-06ee156d94aac3129", # us-east-1d  "subnet-0b3e062053c088aac", #
    "subnet-0213e0b3f4605d21f", # us-east-1e  "subnet-0a787e162b32d4fca", #
    "subnet-0e2fb8a958f218227"  # us-east-1f  "subnet-006273ca9b0ed3190"  #
  ]
}

variable "existing_private_subnet_ids" {
  description = "Existing private subnet IDs (using public for now)"
  type        = list(string)
  default     = []
}

variable "existing_internet_gateway_id" {
  description = "Existing Internet Gateway ID"
  type        = string
  default     = "igw-06e41237e5b852ad6" #"igw-0451d2256ce1787e8" #
}

# ECR repositories configuration
variable "ecr_repositories" {
  description = "List of ECR repositories to create"
  type = list(object({
    name                 = string
    image_tag_mutability = optional(string, "MUTABLE")
    scan_on_push         = optional(bool, true)
    lifecycle_policy     = optional(string, "standard")
    encryption_type      = optional(string, "AES256")
  }))
}

# RDS Configuration
variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro" # Free tier eligible dg.t3.micro
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20 # Free tier provides up to 20 GB
}

variable "rds_database_name" {
  description = "RDS database name"
  type        = string
  default     = "hopjetairline_db"
}

variable "rds_username" {
  description = "RDS master username"
  type        = string
  default     = "hopjetair"
}

variable "rds_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
  default     = "SecurePass123!"
}

# Service Configuration
variable "service_configs" {
  description = "Configuration for each service"
  type = map(object({
    cpu    = number
    memory = number
    count  = number
    port   = number
  }))
  default = {
    frontend-api = {
      cpu    = 512
      memory = 1024
      count  = 1
      port   = 8075
    }
    langgraph-api = {
      cpu    = 1024
      memory = 2048
      count  = 1
      port   = 8065
    }
    intent-api = {
      cpu    = 512
      memory = 1024
      count  = 1
      port   = 8085
    }
    sentiment-api = {
      cpu    = 512
      memory = 1024
      count  = 1
      port   = 8095
    }
    non-ai-api = {
      cpu    = 512
      memory = 1024
      count  = 1
      port   = 8003
    }
    rag-api = {
      cpu    = 1024
      memory = 2048
      count  = 1
      port   = 8080
    }
  }
}
