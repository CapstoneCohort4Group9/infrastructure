variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "ecr_repositories" {
  description = "List of ECR repositories to create"
  type = list(object({
    name                 = string
    image_tag_mutability = optional(string, "MUTABLE")
    scan_on_push        = optional(bool, true)
    lifecycle_policy    = optional(string, "standard")
    encryption_type     = optional(string, "AES256")
  }))
}
