# PowerShell script to migrate from ap-south-1 to us-east-1

param(
    [Parameter(Mandatory=$false)]
    [switch]$SkipDestroy = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipBackendSetup = $false
)

Write-Host "Migration to us-east-1 Script" -ForegroundColor Green
Write-Host "=" * 50 -ForegroundColor Gray

# Set regions
$oldRegion = "ap-south-1"
$newRegion = "us-east-1"

# Step 1: Backup current state
Write-Host "`n[Step 1] Backing up current state..." -ForegroundColor Cyan
terraform state pull > "terraform-state-backup-$(Get-Date -Format 'yyyy-MM-dd-HHmmss').json"
Write-Host "✓ State backed up" -ForegroundColor Green

# Step 2: Destroy resources in ap-south-1
if (-not $SkipDestroy) {
    Write-Host "`n[Step 2] Destroying resources in $oldRegion..." -ForegroundColor Cyan
    Write-Host "This will destroy ECR repositories and secrets in $oldRegion" -ForegroundColor Yellow
    $confirm = Read-Host "Are you sure? (yes/no)"
    
    if ($confirm -eq "yes") {
        terraform destroy -auto-approve
        Write-Host "✓ Resources destroyed" -ForegroundColor Green
    } else {
        Write-Host "Skipping destroy" -ForegroundColor Yellow
    }
} else {
    Write-Host "`n[Step 2] Skipping destroy (--SkipDestroy flag set)" -ForegroundColor Yellow
}

# Step 3: Setup backend resources in us-east-1
if (-not $SkipBackendSetup) {
    Write-Host "`n[Step 3] Setting up backend resources in $newRegion..." -ForegroundColor Cyan
    
    # Update AWS region
    $env:AWS_DEFAULT_REGION = $newRegion
    
    # Run backend setup script
    if (Test-Path ".\setup-terraform-backend.ps1") {
        .\setup-terraform-backend.ps1 -Region $newRegion
    } else {
        Write-Host "Backend setup script not found, creating resources manually..." -ForegroundColor Yellow
        
        # Create S3 bucket
        $bucketName = "terraform-state-bucket-109038807292"
        aws s3api create-bucket `
            --bucket $bucketName `
            --region $newRegion 2>$null
        
        aws s3api put-bucket-versioning `
            --bucket $bucketName `
            --versioning-configuration Status=Enabled
        
        # Create DynamoDB table
        aws dynamodb create-table `
            --table-name terraform-state-lock `
            --attribute-definitions AttributeName=LockID,AttributeType=S `
            --key-schema AttributeName=LockID,KeyType=HASH `
            --billing-mode PAY_PER_REQUEST `
            --region $newRegion 2>$null
    }
    Write-Host "✓ Backend resources ready" -ForegroundColor Green
} else {
    Write-Host "`n[Step 3] Skipping backend setup (--SkipBackendSetup flag set)" -ForegroundColor Yellow
}

# Step 4: Update Terraform files
Write-Host "`n[Step 4] Updating Terraform configuration..." -ForegroundColor Cyan

# Update variables.tf
$variablesContent = Get-Content "variables.tf" -Raw
$variablesContent = $variablesContent -replace 'default\s*=\s*"ap-south-1"', 'default     = "us-east-1"'
Set-Content "variables.tf" -Value $variablesContent

# Update terraform.tfvars
$tfvarsContent = Get-Content "terraform.tfvars" -Raw
$tfvarsContent = $tfvarsContent -replace 'aws_region\s*=\s*"ap-south-1"', 'aws_region  = "us-east-1"'
Set-Content "terraform.tfvars" -Value $tfvarsContent

# Update backend configuration in main.tf
$mainContent = Get-Content "main.tf" -Raw
$mainContent = $mainContent -replace 'region\s*=\s*"ap-south-1"', 'region         = "us-east-1"'
Set-Content "main.tf" -Value $mainContent

Write-Host "✓ Configuration files updated" -ForegroundColor Green

# Step 5: Update secrets in us-east-1
Write-Host "`n[Step 5] Creating secrets in $newRegion..." -ForegroundColor Cyan
if (Test-Path ".\update-secrets-values.ps1") {
    Write-Host "Please update your secrets with the new region:" -ForegroundColor Yellow
    Write-Host ".\update-secrets-values.ps1 -Region us-east-1 -ApiKey 'your-key' -ApiSecret 'your-secret' -DbUsername 'hopjetair' -DbPassword 'your-password'" -ForegroundColor White
} else {
    Write-Host "Secrets update script not found. Please create secrets manually in $newRegion" -ForegroundColor Yellow
}

# Step 6: Initialize Terraform with new backend
Write-Host "`n[Step 6] Initializing Terraform with new backend..." -ForegroundColor Cyan
Remove-Item -Path ".terraform" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path ".terraform.lock.hcl" -Force -ErrorAction SilentlyContinue

# Initialize with new backend
terraform init -reconfigure `
    -backend-config="bucket=terraform-state-bucket-109038807292" `
    -backend-config="key=infrastructure/terraform.tfstate" `
    -backend-config="region=us-east-1" `
    -backend-config="encrypt=true" `
    -backend-config="dynamodb_table=terraform-state-lock"

Write-Host "✓ Terraform initialized" -ForegroundColor Green

# Step 7: Plan the deployment
Write-Host "`n[Step 7] Planning deployment..." -ForegroundColor Cyan
terraform plan -out=tfplan

Write-Host "`n✅ Migration preparation complete!" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Review the plan above" -ForegroundColor White
Write-Host "2. Run: terraform apply tfplan" -ForegroundColor White
Write-Host "3. Build and push Docker images to new ECR repositories" -ForegroundColor White
Write-Host "4. Enable pgvector extension in RDS" -ForegroundColor White

Write-Host "`nIMPORTANT:" -ForegroundColor Red
Write-Host "- Update RDS password in terraform.tfvars before applying!" -ForegroundColor Red
Write-Host "- Create secrets in us-east-1 before deploying services!" -ForegroundColor Red