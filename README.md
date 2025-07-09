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

### 0. Check if you are in the right aws account and region

```
powershell
# Test the command directly
aws sts get-caller-identity

# Should return something like:
# {
#     "UserId": "AIDACKCEVSQ6C2EXAMPLE",
#     "Account": "123456789012",
#     "Arn": "arn:aws:iam::123456789012:user/username"
# }
```

### 1. Follow the instructions specified in the link below

Follow the instruction given in

```powershell
scripts\check-setup.md
```

## Security

- Uses OIDC for AWS authentication (no long-lived credentials)
- Terraform state is encrypted in S3
- State locking prevents concurrent modifications
