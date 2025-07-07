variable "repositories" {
  description = "List of ECR repositories to create"
  type = list(object({
    name                 = string
    image_tag_mutability = optional(string, "MUTABLE")
    scan_on_push        = optional(bool, true)
    lifecycle_policy    = optional(string, "standard")
    encryption_type     = optional(string, "AES256")
  }))
}

variable "environment" {
  description = "Environment name"
  type        = string
}
