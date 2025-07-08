## Script Execution Order and Frequency:

### 1. **setup-aws-oidc.ps1** ✅ (Run ONCE per AWS Account)
```powershell
.\scripts\setup-aws-oidc.ps1
```
- **Purpose**: Creates OIDC provider and IAM role for GitHub Actions
- **When to run**: 
  - Once when setting up a new AWS account
  - If you change GitHub org/repo name
  - If you need to update IAM permissions

### 2. **setup-terraform-backend.ps1** ✅ (Run ONCE per AWS Account/Region)
```powershell
.\scripts\setup-terraform-backend.ps1 -Region us-east-1
```
- **Purpose**: Creates S3 bucket and DynamoDB table for Terraform state
- **When to run**:
  - Once when setting up in a new AWS account
  - If you're using a new region for state storage
  - If you accidentally delete the bucket/table

### 3. **terraform-init.ps1** 🔄 (Run EVERY TIME you need terraform init)
```powershell
.\scripts\terraform-init.ps1
```
- **Purpose**: Configures Terraform to use the backend with your account ID
- **When to run**:
  - First time setting up the project locally
  - After cloning the repo on a new machine
  - When switching between AWS accounts
  - After cleaning .terraform directory
  - When changing backend configuration

## Visual Workflow:

```
First Time Setup:
├── 1. setup-aws-oidc.ps1          [ONCE per account]
├── 2. setup-terraform-backend.ps1   [ONCE per account/region]
└── 3. terraform-init.ps1           [EVERY terraform init]

Daily Development:
└── terraform-init.ps1              [As needed]
```

## Common Scenarios:

### Scenario 1: Fresh Setup
```powershell
# One-time setup
.\scripts\setup-aws-oidc.ps1
.\scripts\setup-terraform-backend.ps1 -Region us-east-1

# Initialize Terraform
.\scripts\terraform-init.ps1

# Normal Terraform workflow
terraform plan
terraform apply
```

### Scenario 2: New Developer Joining Team
```powershell
# They only need to run (backend already exists)
.\scripts\terraform-init.ps1

# Then normal workflow
terraform plan
```

### Scenario 3: Switching AWS Accounts
```powershell
# If backend doesn't exist in new account
.\scripts\setup-terraform-backend.ps1

# Then initialize with new account
.\scripts\terraform-init.ps1 -Reconfigure
```

### Scenario 4: After Cleaning .terraform
```powershell
# Just run
.\scripts\terraform-init.ps1
```

## Pro Tip: Create a Setup Checker ScriptNow you can easily check what's set up:

```powershell
# Check if everything is ready
.\scripts\check-setup.ps1

# If all good, then initialize
.\scripts\terraform-init.ps1
```

This makes it clear what needs to be run and when! 🎯