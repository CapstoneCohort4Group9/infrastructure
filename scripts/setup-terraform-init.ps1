# PowerShell script to initialize Terraform with dynamic backend configuration
# Consolidated version that combines the best of both scripts

param(
    [Parameter(Mandatory=$false)]
    [string]$AccountId = $null,
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "us-east-1",
    
    [Parameter(Mandatory=$false)]
    [string]$Environment = "production",
    
    [Parameter(Mandatory=$false)]
    [switch]$Reconfigure = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$MigrateState = $false
)

Write-Host "Terraform Backend Initialization" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green

# Get AWS Account ID if not provided
if (-not $AccountId) {
    try {
        $AccountId = (aws sts get-caller-identity --query Account --output text).Trim()
        Write-Host "AWS Account ID: $AccountId" -ForegroundColor Yellow
    } catch {
        Write-Host "Error: Unable to get AWS account ID" -ForegroundColor Red
        Write-Host "Make sure AWS CLI is configured: aws configure" -ForegroundColor Yellow
        exit 1
    }
}

# Set backend configuration
$bucketName = "terraform-state-bucket-$AccountId"
$tableName = "terraform-state-lock"
$stateKey = "infrastructure/terraform.tfstate"  # Changed from ecr/terraform.tfstate

Write-Host "`nBackend Configuration:" -ForegroundColor Cyan
Write-Host "  Bucket: $bucketName" -ForegroundColor White
Write-Host "  Key: $stateKey" -ForegroundColor White
Write-Host "  Region: $Region" -ForegroundColor White
Write-Host "  Table: $tableName" -ForegroundColor White
Write-Host "  Environment: $Environment" -ForegroundColor White

# Create backend config file
$backendConfig = @"
# Auto-generated backend configuration
# Generated on: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
# Account ID: $AccountId
# Environment: $Environment

bucket         = "$bucketName"
key            = "$stateKey"
region         = "$Region"
encrypt        = true
dynamodb_table = "$tableName"
"@

# Save to backend-config.hcl
$backendConfigFile = "backend-config.hcl"
Set-Content -Path $backendConfigFile -Value $backendConfig
Write-Host "`nCreated $backendConfigFile" -ForegroundColor Green

# Check if .gitignore exists and add backend-config.hcl if not already there
if (Test-Path ".gitignore") {
    $gitignoreContent = Get-Content ".gitignore" -Raw
    if ($gitignoreContent -notmatch "backend-config\.hcl") {
        Add-Content ".gitignore" "`n# Terraform backend configuration`nbackend-config.hcl`n*.backend.hcl"
        Write-Host "Added backend-config.hcl to .gitignore" -ForegroundColor Green
    }
} else {
    # Create .gitignore if it doesn't exist
    $gitignoreContent = @"
# Terraform backend configuration
backend-config.hcl
*.backend.hcl

# Terraform
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl
*.tfplan
"@
    Set-Content -Path ".gitignore" -Value $gitignoreContent
    Write-Host "Created .gitignore with backend config exclusion" -ForegroundColor Green
}

# Check if we need to migrate from old state location
$oldStateKey = "ecr/terraform.tfstate"
if (-not $Reconfigure -and -not $MigrateState) {
    Write-Host "`nChecking for existing state..." -ForegroundColor Yellow
    
    # Try to check if old state exists (this is a simple check)
    $terraformDir = ".terraform"
    if (Test-Path $terraformDir) {
        Write-Host "Found existing .terraform directory" -ForegroundColor Yellow
        Write-Host "If you're migrating from ecr/terraform.tfstate to infrastructure/terraform.tfstate," -ForegroundColor Yellow
        Write-Host "run with -MigrateState flag" -ForegroundColor Yellow
    }
}

# Initialize Terraform
Write-Host "`nInitializing Terraform..." -ForegroundColor Cyan

$initArgs = @(
    "init",
    "-backend-config=$backendConfigFile"
)

if ($Reconfigure) {
    $initArgs += "-reconfigure"
    Write-Host "Running with -reconfigure flag..." -ForegroundColor Yellow
} elseif ($MigrateState) {
    $initArgs += "-migrate-state"
    Write-Host "Running with -migrate-state flag..." -ForegroundColor Yellow
}

# Execute terraform init
$process = Start-Process -FilePath "terraform" -ArgumentList $initArgs -NoNewWindow -PassThru -Wait

if ($process.ExitCode -eq 0) {
    Write-Host "`n✅ Terraform initialized successfully!" -ForegroundColor Green
    
    Write-Host "`nNext steps:" -ForegroundColor Yellow
    Write-Host "1. Review your terraform.tfvars file" -ForegroundColor White
    Write-Host "2. Run: terraform plan" -ForegroundColor White
    Write-Host "3. Run: terraform apply" -ForegroundColor White
    
    Write-Host "`nTo use this backend config in the future:" -ForegroundColor Cyan
    Write-Host "  terraform init -backend-config=backend-config.hcl" -ForegroundColor White
} else {
    Write-Host "`n❌ Terraform initialization failed!" -ForegroundColor Red
    Write-Host "Check the error messages above for details" -ForegroundColor Yellow
    exit 1
}