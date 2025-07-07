# terraform/terraform-init.ps1
# Helper script to initialize Terraform with the correct backend

param(
    [Parameter(Mandatory=$false)]
    [string]$AccountId = $null,
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "ap-south-1"
)

# Get AWS Account ID if not provided
if (-not $AccountId) {
    try {
        $AccountId = (aws sts get-caller-identity --query Account --output text).Trim()
        Write-Host "Using AWS Account ID: $AccountId" -ForegroundColor Green
    } catch {
        Write-Host "Error: Unable to get AWS account ID" -ForegroundColor Red
        exit 1
    }
}

$bucketName = "terraform-state-bucket-$AccountId"

Write-Host "Initializing Terraform with backend configuration..." -ForegroundColor Yellow
Write-Host "Bucket: $bucketName" -ForegroundColor Cyan
Write-Host "Region: $Region" -ForegroundColor Cyan

# Initialize Terraform with backend config
terraform init `
    -backend-config="bucket=$bucketName" `
    -backend-config="key=ecr/terraform.tfstate" `
    -backend-config="region=$Region" `
    -backend-config="encrypt=true" `
    -backend-config="dynamodb_table=terraform-state-lock"

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✅ Terraform initialized successfully!" -ForegroundColor Green
    
    # Create backend-config.hcl for future use
    $backendConfig = @"
# Auto-generated backend configuration
# Generated on: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
bucket         = "$bucketName"
key            = "ecr/terraform.tfstate"
region         = "$Region"
encrypt        = true
dynamodb_table = "terraform-state-lock"
"@
    
    Set-Content -Path "backend-config.hcl" -Value $backendConfig
    Write-Host "`nBackend configuration saved to: backend-config.hcl" -ForegroundColor Yellow
    Write-Host "Add this file to .gitignore!" -ForegroundColor Red
} else {
    Write-Host "`n❌ Terraform initialization failed!" -ForegroundColor Red
    exit 1
}