terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    bucket         = "terraform-state-bucket-${data.aws_caller_identity.current.account_id}"
    key            = "ecr/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

data "aws_caller_identity" "current" {}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = "infrastructure"
    }
  }
}

# ECR Repositories
module "ecr" {
  source = "./modules/ecr"
  
  repositories = var.ecr_repositories
  environment  = var.environment
}

# Secrets Management
module "secrets" {
  source = "./modules/secrets"
  
  environment = var.environment
}