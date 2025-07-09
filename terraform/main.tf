terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Option 1: Empty backend block - configure during init
  backend "s3" {
    # Backend configuration provided during terraform init
  }
}

data "aws_caller_identity" "current" {}

provider "aws" {
  region = var.aws_region #us-east-1

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = "infrastructure"
      Project     = var.project_name
    }
  }
}

# ECR Repositories
module "ecr" {
  source = "./modules/ecr"

  repositories = var.ecr_repositories
  environment  = var.environment
  project      = var.project_name
}

# Secrets Management
module "secrets" {
  source = "./modules/secrets"

  environment = var.environment
  project     = var.project_name

  # Override defaults with your values
  api_key    = var.api_key
  api_secret = var.api_secret
  db_user    = var.db_user
  db_pass    = var.db_pass
}

# Import existing VPC resources (from your Bedrock setup)
module "networking" {
  source = "./modules/networking"

  vpc_id              = var.existing_vpc_id
  public_subnet_ids   = var.existing_public_subnet_ids
  private_subnet_ids  = var.existing_private_subnet_ids
  internet_gateway_id = var.existing_internet_gateway_id
}

# Security groups
module "security" {
  source = "./modules/security"

  vpc_id                = module.networking.vpc_id
  vpc_cidr              = module.networking.vpc_cidr_block
  alb_security_group_id = module.alb.security_group_id
  environment           = var.environment
  project               = var.project_name
}

# RDS PostgreSQL
module "rds" {
  source = "./modules/rds"

  identifier        = "${var.project_name}-postgres"
  db_name           = var.rds_database_name
  username          = module.secrets.db_credentials_parsed.db_user
  password          = module.secrets.db_credentials_parsed.db_pass
  instance_class    = var.rds_instance_class
  allocated_storage = var.rds_allocated_storage

  vpc_id            = module.networking.vpc_id
  subnet_ids        = module.networking.public_subnet_ids
  security_group_id = module.security.rds_security_group_id

  publicly_accessible = true

  environment = var.environment
  project     = var.project_name
}

# ECS Cluster
module "ecs_cluster" {
  source = "./modules/ecs-cluster"

  cluster_name = "${var.project_name}-cluster"
  environment  = var.environment
  project      = var.project_name

  enable_container_insights = true
}

# ALB for frontend in us-east-1
module "alb" {
  source = "./modules/alb"

  # providers = {
  #   aws = aws.region
  # }

  name               = "${var.project_name}-alb"
  vpc_id             = module.networking.vpc_id
  subnet_ids         = module.networking.public_subnet_ids
  security_group_ids = [module.security.alb_security_group_id]

  environment = var.environment
  project     = var.project_name
}

# Service Discovery Namespace in us-east-1
resource "aws_service_discovery_private_dns_namespace" "main" {
  # provider = aws.us_east_1

  name        = "${var.project_name}.local"
  description = "Private DNS namespace for ${var.project_name} services"
  vpc         = module.networking.vpc_id

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Frontend API Service (Public via ALB)
locals {
  frontend_api     = "frontend-api"
  langgraph_api    = "langgraph-api"
  intent_api       = "intent-api"
  sentiment_api    = "sentiment-api"
  non_ai_api       = "non-ai-api"
  rag_api          = "rag-api"
  bedrock_model_id = "hopjetair-chat-model"
}

module "frontend_api" {
  source = "./modules/ecs-service"

  service_name       = local.frontend_api
  cluster_id         = module.ecs_cluster.cluster_id
  task_role_arn      = module.ecs_cluster.task_role_arn
  execution_role_arn = module.ecs_cluster.task_execution_role_arn

  container_name   = local.frontend_api
  container_port   = var.service_configs[local.frontend_api].port
  container_image  = "${module.ecr.repository_urls[local.frontend_api]}:latest"
  container_cpu    = var.service_configs[local.frontend_api].cpu
  container_memory = var.service_configs[local.frontend_api].memory
  desired_count    = var.service_configs[local.frontend_api].count

  vpc_id             = module.networking.vpc_id
  subnet_ids         = module.networking.public_subnet_ids
  security_group_ids = [module.security.ecs_service_security_group_id]

  # ALB configuration
  enable_load_balancer = true
  target_group_arn     = module.alb.target_group_arn

  # Service discovery
  enable_service_discovery    = true
  service_discovery_namespace = aws_service_discovery_private_dns_namespace.main.id

  environment_variables = {
    NODE_ENV          = var.environment
    LANGGRAPH_API_URL = "http://${local.langgraph_api}.${var.project_name}.local:${var.service_configs[local.langgraph_api].port}"
    PORT              = tostring(var.service_configs[local.frontend_api].port)
  }

  environment = var.environment
  project     = var.project_name


}

# LangGraph API Service (Internal)
module "langgraph_api" {
  source = "./modules/ecs-service"

  service_name       = local.langgraph_api
  cluster_id         = module.ecs_cluster.cluster_id
  task_role_arn      = module.ecs_cluster.task_role_arn
  execution_role_arn = module.ecs_cluster.task_execution_role_arn

  container_name   = local.langgraph_api
  container_port   = var.service_configs[local.langgraph_api].port
  container_image  = "${module.ecr.repository_urls[local.langgraph_api]}:latest"
  container_cpu    = var.service_configs[local.langgraph_api].cpu
  container_memory = var.service_configs[local.langgraph_api].memory
  desired_count    = var.service_configs[local.langgraph_api].count

  vpc_id             = module.networking.vpc_id
  subnet_ids         = module.networking.public_subnet_ids
  security_group_ids = [module.security.ecs_service_security_group_id]

  enable_load_balancer        = false
  enable_service_discovery    = true
  service_discovery_namespace = aws_service_discovery_private_dns_namespace.main.id

  environment_variables = {
    PORT              = tostring(var.service_configs[local.langgraph_api].port)
    INTENT_API_URL    = "http://${local.intent_api}.${var.project_name}.local:${var.service_configs[local.intent_api].port}"
    SENTIMENT_API_URL = "http://${local.sentiment_api}.${var.project_name}.local:${var.service_configs[local.sentiment_api].port}"
    NON_AI_API_URL    = "http://${local.non_ai_api}.${var.project_name}.local:${var.service_configs[local.non_ai_api].port}"
    RAG_API_URL       = "http://${local.rag_api}.${var.project_name}.local:${var.service_configs[local.rag_api].port}"
    BEDROCK_MODEL_ID  = local.bedrock_model_id
    AWS_REGION        = var.aws_region
    API_KEY           = module.secrets.api_secrets_parsed.api_key
  }

  environment = var.environment
  project     = var.project_name
}

# Intent API Service
module "intent_api" {
  source = "./modules/ecs-service"

  service_name       = local.intent_api
  cluster_id         = module.ecs_cluster.cluster_id
  task_role_arn      = module.ecs_cluster.task_role_arn
  execution_role_arn = module.ecs_cluster.task_execution_role_arn

  container_name   = local.intent_api
  container_port   = var.service_configs[local.intent_api].port
  container_image  = "${module.ecr.repository_urls[local.intent_api]}:latest"
  container_cpu    = var.service_configs[local.intent_api].cpu
  container_memory = var.service_configs[local.intent_api].memory
  desired_count    = var.service_configs[local.intent_api].count

  vpc_id             = module.networking.vpc_id
  subnet_ids         = module.networking.public_subnet_ids
  security_group_ids = [module.security.ecs_service_security_group_id]

  enable_load_balancer        = false
  enable_service_discovery    = true
  service_discovery_namespace = aws_service_discovery_private_dns_namespace.main.id

  environment_variables = {
    PORT = tostring(var.service_configs[local.intent_api].port)
  }

  environment = var.environment
  project     = var.project_name
}

# Sentiment API Service
module "sentiment_api" {
  source = "./modules/ecs-service"

  service_name       = local.sentiment_api
  cluster_id         = module.ecs_cluster.cluster_id
  task_role_arn      = module.ecs_cluster.task_role_arn
  execution_role_arn = module.ecs_cluster.task_execution_role_arn

  container_name   = local.sentiment_api
  container_port   = var.service_configs[local.sentiment_api].port
  container_image  = "${module.ecr.repository_urls[local.sentiment_api]}:latest"
  container_cpu    = var.service_configs[local.sentiment_api].cpu
  container_memory = var.service_configs[local.sentiment_api].memory
  desired_count    = var.service_configs[local.sentiment_api].count

  vpc_id             = module.networking.vpc_id
  subnet_ids         = module.networking.public_subnet_ids
  security_group_ids = [module.security.ecs_service_security_group_id]

  enable_load_balancer        = false
  enable_service_discovery    = true
  service_discovery_namespace = aws_service_discovery_private_dns_namespace.main.id

  environment_variables = {
    PORT = tostring(var.service_configs[local.sentiment_api].port)
  }

  environment = var.environment
  project     = var.project_name
}

# Non-AI API Service
module "non_ai_api" {
  source = "./modules/ecs-service"

  service_name       = local.non_ai_api
  cluster_id         = module.ecs_cluster.cluster_id
  task_role_arn      = module.ecs_cluster.task_role_arn
  execution_role_arn = module.ecs_cluster.task_execution_role_arn

  container_name   = local.non_ai_api
  container_port   = var.service_configs[local.non_ai_api].port
  container_image  = "${module.ecr.repository_urls[local.non_ai_api]}:latest"
  container_cpu    = var.service_configs[local.non_ai_api].cpu
  container_memory = var.service_configs[local.non_ai_api].memory
  desired_count    = var.service_configs[local.non_ai_api].count

  vpc_id             = module.networking.vpc_id
  subnet_ids         = module.networking.public_subnet_ids
  security_group_ids = [module.security.ecs_service_security_group_id]

  enable_load_balancer        = false
  enable_service_discovery    = true
  service_discovery_namespace = aws_service_discovery_private_dns_namespace.main.id

  # Health check configuration
  enable_health_check       = true
  health_check_path         = "/health-deep"
  health_check_interval     = 30
  health_check_timeout      = 10
  health_check_retries      = 3
  health_check_start_period = 60

  environment_variables = {
    PORT    = tostring(var.service_configs[local.non_ai_api].port)
    DB_HOST = module.rds.address
    DB_PORT = tostring(module.rds.port)
    DB_NAME = var.rds_database_name
    DB_USER = module.secrets.db_credentials_parsed.db_user
    DB_PASS = module.secrets.db_credentials_parsed.db_pass
  }

  environment = var.environment
  project     = var.project_name
}

# RAG API Service
module "rag_api" {
  source = "./modules/ecs-service"

  service_name       = local.rag_api
  cluster_id         = module.ecs_cluster.cluster_id
  task_role_arn      = module.ecs_cluster.task_role_arn
  execution_role_arn = module.ecs_cluster.task_execution_role_arn

  container_name   = local.rag_api
  container_port   = var.service_configs[local.rag_api].port
  container_image  = "${module.ecr.repository_urls[local.rag_api]}:latest"
  container_cpu    = var.service_configs[local.rag_api].cpu
  container_memory = var.service_configs[local.rag_api].memory
  desired_count    = var.service_configs[local.rag_api].count

  vpc_id             = module.networking.vpc_id
  subnet_ids         = module.networking.public_subnet_ids
  security_group_ids = [module.security.ecs_service_security_group_id]

  enable_load_balancer        = false
  enable_service_discovery    = true
  service_discovery_namespace = aws_service_discovery_private_dns_namespace.main.id

  environment_variables = {
    PORT             = tostring(var.service_configs[local.rag_api].port)
    DB_HOST          = module.rds.address
    DB_PORT          = tostring(module.rds.port)
    DB_NAME          = var.rds_database_name
    BEDROCK_MODEL_ID = local.bedrock_model_id
    AWS_REGION       = var.aws_region
    DB_USER          = module.secrets.db_credentials_parsed.db_user
    DB_PASS          = module.secrets.db_credentials_parsed.db_pass
  }

  environment = var.environment
  project     = var.project_name
}
