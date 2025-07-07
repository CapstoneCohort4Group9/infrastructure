# Infrastructure as Code with Terraform

This repository manages AWS infrastructure using Terraform and GitHub Actions with OIDC authentication.

## Structure

```
├── .github/workflows/     # GitHub Actions workflows
├── terraform/            # Terraform configurations
│   └── modules/         # Reusable Terraform modules
└── scripts/             # Setup and utility scripts
```

## Prerequisites

1. AWS Account with appropriate permissions
2. GitHub repository with OIDC provider configured
3. S3 bucket for Terraform state
4. DynamoDB table for state locking

## profile set and reset
```powershell
$env:AWS_PROFILE = "hopjetair"
#once you finished using please remove it
Remove-Item Env:AWS_PROFILE
```

## Initial Setup

### 1. Configure AWS OIDC Provider (One-time setup)

Run the setup script to create OIDC provider and IAM role:

```powershell
cd scripts
.\setup-aws-oidc.ps1
```

### 2. Create Backend Resources

Create S3 bucket and DynamoDB table for Terraform state:

```powershell
cd scripts
.\setup-terraform-backend.ps1
```

### 3. Configure GitHub Secrets

Add these repository variables in GitHub:

- `AWS_ACCOUNT_ID`: Your AWS account ID
- `AWS_REGION`: Your preferred AWS region (e.g., ap-south-1)

## Usage

### Adding New ECR Repository

1. Edit `terraform\terraform.tfvars`
2. Add new repository to the `ecr_repositories` list
3. Create a pull request
4. GitHub Actions will run `terraform plan`
5. Merge PR to apply changes

### Manual Terraform Commands

```powershell
cd terraform
terraform init
terraform plan
terraform apply
```

## Security

- Uses OIDC for AWS authentication (no long-lived credentials)
- Terraform state is encrypted in S3
- State locking prevents concurrent modifications
