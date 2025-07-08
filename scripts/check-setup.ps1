# Script to check if all prerequisites are set up

param(
    [Parameter(Mandatory=$false)]
    [string]$Region = "us-east-1"
)

Write-Host "Checking Terraform Infrastructure Prerequisites" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green

$allGood = $true
$accountId = ""

# Get Account ID
try {
    $accountId = (aws sts get-caller-identity --query Account --output text).Trim()
    Write-Host "`n✓ AWS CLI configured - Account ID: $accountId" -ForegroundColor Green
} catch {
    Write-Host "`n✗ AWS CLI not configured" -ForegroundColor Red
    Write-Host "  Run: aws configure" -ForegroundColor Yellow
    $allGood = $false
    exit 1
}

# Check OIDC Provider
Write-Host "`nChecking OIDC Provider..." -ForegroundColor Cyan
$oidcProviderArn = "arn:aws:iam::${accountId}:oidc-provider/token.actions.githubusercontent.com"
$null = aws iam get-open-id-connect-provider --open-id-connect-provider-arn $oidcProviderArn 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ OIDC Provider exists" -ForegroundColor Green
} else {
    Write-Host "✗ OIDC Provider not found" -ForegroundColor Red
    Write-Host "  Run: .\scripts\setup-aws-oidc.ps1" -ForegroundColor Yellow
    $allGood = $false
}

# Check IAM Role
Write-Host "`nChecking IAM Role..." -ForegroundColor Cyan
$null = aws iam get-role --role-name GitHubActionsRole 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ GitHubActionsRole exists" -ForegroundColor Green
} else {
    Write-Host "✗ GitHubActionsRole not found" -ForegroundColor Red
    Write-Host "  Run: .\scripts\setup-aws-oidc.ps1" -ForegroundColor Yellow
    $allGood = $false
}

# Check S3 Backend Bucket
Write-Host "`nChecking S3 Backend..." -ForegroundColor Cyan
$bucketName = "terraform-state-bucket-$accountId"
$null = aws s3api head-bucket --bucket $bucketName --region $Region 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ S3 bucket exists: $bucketName" -ForegroundColor Green
} else {
    Write-Host "✗ S3 bucket not found: $bucketName" -ForegroundColor Red
    Write-Host "  Run: .\scripts\setup-terraform-backend.ps1 -Region $Region" -ForegroundColor Yellow
    $allGood = $false
}

# Check DynamoDB Table
Write-Host "`nChecking DynamoDB Table..." -ForegroundColor Cyan
$tableName = "terraform-state-lock"
$null = aws dynamodb describe-table --table-name $tableName --region $Region 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ DynamoDB table exists: $tableName" -ForegroundColor Green
} else {
    Write-Host "✗ DynamoDB table not found: $tableName" -ForegroundColor Red
    Write-Host "  Run: .\scripts\setup-terraform-backend.ps1 -Region $Region" -ForegroundColor Yellow
    $allGood = $false
}

# Check Terraform installation
Write-Host "`nChecking Terraform..." -ForegroundColor Cyan
try {
    $tfVersion = terraform version -json | ConvertFrom-Json
    Write-Host "✓ Terraform installed: v$($tfVersion.terraform_version)" -ForegroundColor Green
} catch {
    Write-Host "✗ Terraform not installed" -ForegroundColor Red
    Write-Host "  Install from: https://www.terraform.io/downloads" -ForegroundColor Yellow
    $allGood = $false
}

# Summary
Write-Host "`n" + "="*50 -ForegroundColor Gray
if ($allGood) {
    Write-Host "✅ All prerequisites are set up!" -ForegroundColor Green
    Write-Host "`nYou can now run:" -ForegroundColor Yellow
    Write-Host "  .\scripts\terraform-init.ps1" -ForegroundColor White
    Write-Host "  terraform plan" -ForegroundColor White
    Write-Host "  terraform apply" -ForegroundColor White
} else {
    Write-Host "❌ Some prerequisites are missing!" -ForegroundColor Red
    Write-Host "`nPlease run the setup scripts mentioned above in order." -ForegroundColor Yellow
}