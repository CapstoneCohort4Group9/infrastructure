# terraform/modules/ecr/main.tf

locals {
  # Define lifecycle policies
  lifecycle_policies = {
    # Your requested policy - keeps only 1 untagged image
    standard = jsonencode({
      rules = [
        {
          rulePriority = 1
          description  = "Keep only one untagged image, expire all others"
          selection = {
            tagStatus   = "untagged"
            countType   = "imageCountMoreThan"
            countNumber = 1
          }
          action = {
            type = "expire"
          }
        }
      ]
    })

    # Extended policy - keeps more images
    extended = jsonencode({
      rules = [
        {
          rulePriority = 1
          description  = "Keep only one untagged image"
          selection = {
            tagStatus   = "untagged"
            countType   = "imageCountMoreThan"
            countNumber = 1
          }
          action = {
            type = "expire"
          }
        },
        {
          rulePriority = 2
          description  = "Keep last 20 tagged images"
          selection = {
            tagStatus     = "tagged"
            tagPrefixList = ["v"]
            countType     = "imageCountMoreThan"
            countNumber   = 20
          }
          action = {
            type = "expire"
          }
        }
      ]
    })

    # ML-specific policy
    ml-specific = jsonencode({
      rules = [
        {
          rulePriority = 1
          description  = "Keep only one untagged image"
          selection = {
            tagStatus   = "untagged"
            countType   = "imageCountMoreThan"
            countNumber = 1
          }
          action = {
            type = "expire"
          }
        },
        {
          rulePriority = 2
          description  = "Keep last 5 production images"
          selection = {
            tagStatus     = "tagged"
            tagPrefixList = ["prod-"]
            countType     = "imageCountMoreThan"
            countNumber   = 5
          }
          action = {
            type = "expire"
          }
        },
        {
          rulePriority = 3
          description  = "Keep last 30 model images"
          selection = {
            tagStatus     = "tagged"
            tagPrefixList = ["model-"]
            countType     = "imageCountMoreThan"
            countNumber   = 30
          }
          action = {
            type = "expire"
          }
        }
      ]
    })

    # Minimal policy - your exact requirement, nothing else
    minimal = jsonencode({
      rules = [
        {
          rulePriority = 1
          description  = "Keep only one untagged image, expire all others"
          selection = {
            tagStatus   = "untagged"
            countType   = "imageCountMoreThan"
            countNumber = 1
          }
          action = {
            type = "expire"
          }
        }
      ]
    })
  }
}

resource "aws_ecr_repository" "this" {
  for_each = { for repo in var.repositories : repo.name => repo }

  name                 = each.value.name
  image_tag_mutability = each.value.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = each.value.scan_on_push
  }

  encryption_configuration {
    encryption_type = each.value.encryption_type
  }

  tags = {
    Name        = each.value.name
    Environment = var.environment
    Project     = var.project
  }
}

# This resource creates the lifecycle policy for each repository
resource "aws_ecr_lifecycle_policy" "this" {
  for_each = { for repo in var.repositories : repo.name => repo }

  repository = aws_ecr_repository.this[each.key].name

  # This line selects which policy to use based on the repository's lifecycle_policy setting
  # If not specified, it defaults to "standard" which is your requested policy
  policy = lookup(local.lifecycle_policies, each.value.lifecycle_policy, local.lifecycle_policies.standard)
}
