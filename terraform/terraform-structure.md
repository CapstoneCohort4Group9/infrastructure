# Terraform Infrastructure Structure

## Architecture Overview

```
┌─────────────────┐
│   ALB (Public)  │
│   DNS Entry     │
└────────┬────────┘
         │ :8075
    ┌────▼─────┐
    │ Frontend │ (ReactJS - Fargate)
    │   API    │
    └────┬─────┘
         │
    ┌────▼─────────┐
    │  LangGraph   │ (Fargate :8065)
    │     API      │ ◄── Orchestrator
    └──┬─┬─┬─┬─┬──┘
       │ │ │ │ │
       │ │ │ │ └─────► Bedrock Model
       │ │ │ │         (hopjetair-chat-model)
       │ │ │ │
       │ │ │ └───────► RAG API (:8080)
       │ │ │                │
       │ │ │                ▼
       │ │ │           PostgreSQL
       │ │ │           (pgvector)
       │ │ │
       │ │ └─────────► Non-AI API (:8003)
       │ │                  │
       │ │                  ▼
       │ │             PostgreSQL
       │ │
       │ └───────────► Sentiment API (:8095)
       │
       └─────────────► Intent API (:8085)
```

## Module Structure

```
terraform/
├── main.tf                 # Root module
├── variables.tf            # Global variables
├── outputs.tf              # Global outputs
├── terraform.tfvars        # Variable values
│
├── modules/
│   ├── secrets/              # secret management
│   │   ├── main.tf
│   │   └── variables.tf
│   │
│   ├── ecr/                  # ECR image
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── networking/      # Import existing VPC resources
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── rds/                  # PostgreSQL with pgvector
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── ecs-cluster/       # ECS Cluster
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── ecs-service/     # Reusable ECS Service module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── alb/                  # Application Load Balancer
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   └── security/          # Security groups
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
```

## Services Configuration

| Service       | Port | Type    | Exposed  | Dependencies        |
| ------------- | ---- | ------- | -------- | ------------------- |
| frontend-api  | 8075 | Fargate | Via ALB  | langgraph-api       |
| langgraph-api | 8065 | Fargate | Internal | All services        |
| intent-api    | 8085 | Fargate | Internal | None                |
| sentiment-api | 8095 | Fargate | Internal | None                |
| non-ai-api    | 8003 | Fargate | Internal | PostgreSQL          |
| rag-api       | 8080 | Fargate | Internal | PostgreSQL, Bedrock |

## Key Decisions

1. **Single VPC**: Use existing VPC (vpc-01233dc74a0ff1a87)
2. **Service Discovery**: AWS Cloud Map for internal service communication
3. **ALB**: Only for frontend-api, others use service discovery
4. **RDS**: PostgreSQL with pgvector extension in private subnets
5. **Secrets**: Use existing Secrets Manager setup
6. **ECR**: Use existing ECR repositories
