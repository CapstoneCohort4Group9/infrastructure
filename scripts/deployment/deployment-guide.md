# Deployment Guide for HopJetAir Infrastructure

## Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Terraform** >= 1.0 installed
3. **Docker** installed (for building and pushing images)
4. **Existing Resources** (from your setup):
   - ECR repositories for all services
   - Secrets in AWS Secrets Manager (api_secrets, db_credentials)
   - Default VPC in us-east-1 with subnets
   - Bedrock model: hopjetair-chat-model

## Step-by-Step Deployment

### 1. Prepare Configuration

```bash
# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
# IMPORTANT: Update the RDS password!
nano terraform.tfvars
```

### 2. Update Secrets in AWS Secrets Manager

```powershell
# Update database credentials (if not already done)
.\scripts\update-secrets-values.ps1 `
  -DbUsername "hopjetair" `
  -DbPassword "YourSecurePassword123!" `
  -Region "us-east-1"
```

### 3. Initialize Terraform

```bash
cd terraform
terraform init
```

### 4. Review the Plan

```bash
terraform plan
```

This will create:
- Security groups for ALB, ECS services, and RDS
- RDS PostgreSQL instance with pgvector
- ECS cluster
- ALB for frontend access
- Service discovery namespace
- 6 ECS services (frontend, langgraph, intent, sentiment, non-ai, rag)

### 5. Deploy Infrastructure

```bash
terraform apply
```

Type `yes` when prompted. This will take about 10-15 minutes.

### 6. Enable pgvector Extension

After RDS is created, connect and enable pgvector:

```bash
# Get RDS endpoint from Terraform output
terraform output -raw rds_endpoint

# Connect using psql or any PostgreSQL client
psql -h <rds-endpoint> -U hopjetair -d hopjetair

# In PostgreSQL prompt:
CREATE EXTENSION IF NOT EXISTS vector;
\q
```

### 7. Build and Push Docker Images

For each service, build and push to ECR:

```bash
# Get ECR URLs
terraform output ecr_repositories

# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com

# For each service (example for frontend-api):
cd ../frontend-api
docker build -t frontend-api .
docker tag frontend-api:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/frontend-api:latest
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/frontend-api:latest
```

### 8. Update ECS Services

After pushing images, update ECS services to use new images:

```bash
# Force new deployment for each service
aws ecs update-service --cluster hopjetair-cluster --service frontend-api --force-new-deployment
aws ecs update-service --cluster hopjetair-cluster --service langgraph-api --force-new-deployment
# ... repeat for all services
```

## Service Endpoints

After deployment:

- **Frontend**: `http://<alb-dns-name>` (public)
- **Internal Services** (via service discovery):
  - LangGraph: `http://langgraph-api.hopjetair.local:8065`
  - Intent: `http://intent-api.hopjetair.local:8085`
  - Sentiment: `http://sentiment-api.hopjetair.local:8095`
  - Non-AI: `http://non-ai-api.hopjetair.local:8003`
  - RAG: `http://rag-api.hopjetair.local:8080`

## Monitoring

### CloudWatch Logs
Each service has its own log group:
- `/ecs/frontend-api`
- `/ecs/langgraph-api`
- `/ecs/intent-api`
- `/ecs/sentiment-api`
- `/ecs/non-ai-api`
- `/ecs/rag-api`

### ECS Console
Monitor services at: https://console.aws.amazon.com/ecs/home?region=us-east-1

## Troubleshooting

### Service Won't Start

1. Check CloudWatch logs:
```bash
aws logs tail /ecs/<service-name> --follow
```

2. Check task definition environment variables
3. Verify security group rules
4. Check if image exists in ECR

### Database Connection Issues

1. Verify RDS security group allows traffic from ECS services
2. Check database credentials in Secrets Manager
3. Ensure pgvector extension is enabled

### Service Discovery Issues

1. Verify services are registered:
```bash
aws servicediscovery list-services --filters Name=NAMESPACE_ID,Values=<namespace-id>
```

2. Check DNS resolution from within a container

### ALB Health Check Failures

1. Ensure frontend app responds to `/` with 200 status
2. Check security group rules
3. Verify target group health check settings

## Cost Optimization

### Current Setup (Estimated Monthly Cost)
- **RDS**: ~$15 (t3.micro)
- **ECS Fargate**: ~$50-100 (depending on usage)
- **ALB**: ~$20
- **Total**: ~$85-135/month

### Cost Saving Tips
1. Use Fargate Spot for non-critical services
2. Schedule services to stop during off-hours
3. Use smaller task sizes for development
4. Enable RDS auto-stop for development

## Updating Services

### Update Service Image
```bash
# Build and push new image
docker build -t <service-name> .
docker tag <service-name>:latest <ecr-url>:latest
docker push <ecr-url>:latest

# Force new deployment
aws ecs update-service --cluster hopjetair-cluster --service <service-name> --force-new-deployment
```

### Update Infrastructure
```bash
# Make changes to .tf files
terraform plan
terraform apply
```

### Scale Services
```bash
# Update desired count
aws ecs update-service --cluster hopjetair-cluster --service <service-name> --desired-count 3
```

## Cleanup

To destroy all resources:
```bash
terraform destroy
```

**WARNING**: This will delete:
- RDS instance (and all data)
- ECS services and cluster
- ALB
- Security groups

ECR repositories and images will remain.

## Next Steps

1. Set up CI/CD pipeline for automated deployments
2. Configure auto-scaling for services
3. Add CloudWatch alarms for monitoring
4. Set up backup strategy for RDS
5. Implement API Gateway if needed for API management
6. Add custom domain with Route53