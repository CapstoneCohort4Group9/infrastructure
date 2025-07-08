# Deployment Checklist - Single Region (us-east-1)

## Pre-Deployment Steps

### 1. Clean Up ap-south-1 (if needed)
```bash
# Destroy existing resources in ap-south-1
cd terraform
terraform destroy -auto-approve
```

### 2. Update Configuration Files
- [x] Update `main.tf` with new single-region configuration
- [x] Update `variables.tf` to use `us-east-1`
- [x] Update `terraform.tfvars` with:
  - [ ] aws_region = "us-east-1"
  - [ ] **IMPORTANT**: Change RDS password from default
  - [ ] Verify existing VPC/subnet IDs are correct

### 3. Setup Backend in us-east-1
```powershell
# Run backend setup for us-east-1
.\scripts\setup-terraform-backend.ps1 -Region us-east-1

# Or use the migration script
.\scripts\migrate-to-us-east-1.ps1
```

### 4. Update GitHub Actions Variables
In GitHub repository settings, update:
- `AWS_REGION`: Change from `ap-south-1` to `us-east-1`

## Deployment Steps

### 1. Initialize Terraform
```bash
cd terraform
rm -rf .terraform .terraform.lock.hcl
terraform init -reconfigure
```

### 2. Create Secrets in us-east-1
```powershell
# Update secrets in new region
.\scripts\update-secrets-values.ps1 `
  -Region us-east-1 `
  -ApiKey "your-api-key" `
  -ApiSecret "your-api-secret" `
  -DbUsername "hopjetair" `
  -DbPassword "YourSecurePassword123!"
```

### 3. Deploy Infrastructure
```bash
# Plan first
terraform plan -out=tfplan

# Review the plan - should create:
# - 6 ECR repositories
# - 2 Secrets
# - Security groups
# - RDS instance
# - ECS cluster
# - ALB
# - 6 ECS services

# Apply
terraform apply tfplan
```

### 4. Post-Deployment Tasks

#### Enable pgvector in RDS
```bash
# Get RDS endpoint
terraform output -raw rds_endpoint

# Connect and enable pgvector
psql -h <endpoint> -U hopjetair -d hopjetair -c "CREATE EXTENSION IF NOT EXISTS vector;"
```

#### Build and Push Docker Images
```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 109038807292.dkr.ecr.us-east-1.amazonaws.com

# For each service:
cd ../services/frontend-api
docker build -t frontend-api .
docker tag frontend-api:latest 109038807292.dkr.ecr.us-east-1.amazonaws.com/frontend-api:latest
docker push 109038807292.dkr.ecr.us-east-1.amazonaws.com/frontend-api:latest

# Repeat for: langgraph-api, intent-api, sentiment-api, non-ai-api, rag-api
```

#### Force Service Updates
```bash
# After pushing images, force new deployments
aws ecs update-service --cluster hopjetair-cluster --service frontend-api --force-new-deployment --region us-east-1
aws ecs update-service --cluster hopjetair-cluster --service langgraph-api --force-new-deployment --region us-east-1
# ... repeat for all services
```

## Verification

### 1. Check Deployment Status
```powershell
.\scripts\check-deployment.ps1 -Region us-east-1
```

### 2. Test Frontend
```bash
# Get ALB URL
terraform output alb_url

# Test frontend
curl <alb-url>
```

### 3. Check Service Logs
```bash
# View logs for any service
aws logs tail /ecs/frontend-api --follow --region us-east-1
```

### 4. Verify Internal Communication
- Frontend should connect to LangGraph API
- LangGraph should connect to all other services
- RAG and Non-AI APIs should connect to RDS

## Troubleshooting

### Common Issues

1. **Services not starting**
   - Check CloudWatch logs
   - Verify ECR images exist
   - Check security group rules

2. **Database connection fails**
   - Verify RDS security group allows access
   - Check secrets are created in us-east-1
   - Ensure pgvector extension is enabled

3. **Service discovery not working**
   - Verify namespace was created
   - Check service registration
   - Test DNS resolution from within VPC

### Rollback Plan
```bash
# If needed, destroy everything
terraform destroy -auto-approve
```

## Cost Optimization

After successful deployment:
1. Consider using Fargate Spot for non-critical services
2. Set up auto-scaling policies
3. Enable S3 lifecycle policies for logs
4. Schedule non-production services to stop after hours

## Success Criteria

- [ ] All 6 services running in ECS
- [ ] Frontend accessible via ALB
- [ ] RDS instance available with pgvector
- [ ] All services healthy in target groups
- [ ] Internal service communication working
- [ ] Bedrock integration functional

## Next Steps

1. Set up monitoring and alerts
2. Configure auto-scaling
3. Add custom domain with Route53
4. Set up CI/CD pipeline
5. Implement backup strategy