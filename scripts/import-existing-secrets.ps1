# PowerShell script to import existing secrets into Terraform state

param(
    [Parameter(Mandatory=$false)]
    [string]$Region = "ap-south-1"
)

Write-Host "Importing existing AWS Secrets into Terraform state..." -ForegroundColor Green

# Set AWS region
$env:AWS_DEFAULT_REGION = $Region

# Get current AWS account ID
try {
    $accountId = (aws sts get-caller-identity --query Account --output text).Trim()
    Write-Host "AWS Account ID: $accountId" -ForegroundColor Yellow
} catch {
    Write-Host "Error: Unable to get AWS account ID" -ForegroundColor Red
    exit 1
}

# Function to check if secret exists
function Test-SecretExists {
    param([string]$SecretName)
    
    try {
        $null = aws secretsmanager describe-secret --secret-id $SecretName --region $Region 2>&1
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

# Import api_secrets
if (Test-SecretExists -SecretName "api_secrets") {
    Write-Host "`nImporting api_secrets..." -ForegroundColor Yellow
    
    # Get the full ARN
    $apiSecretArn = aws secretsmanager describe-secret --secret-id api_secrets --query ARN --output text
    Write-Host "ARN: $apiSecretArn" -ForegroundColor Cyan
    
    # Import into Terraform
    terraform import module.secrets.aws_secretsmanager_secret.api_secrets $apiSecretArn
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ api_secrets imported successfully" -ForegroundColor Green
    } else {
        Write-Host "❌ Failed to import api_secrets" -ForegroundColor Red
    }
} else {
    Write-Host "⚠️  api_secrets does not exist in AWS" -ForegroundColor Yellow
}

# Import db_credentials
if (Test-SecretExists -SecretName "db_credentials") {
    Write-Host "`nImporting db_credentials..." -ForegroundColor Yellow
    
    # Get the full ARN
    $dbSecretArn = aws secretsmanager describe-secret --secret-id db_credentials --query ARN --output text
    Write-Host "ARN: $dbSecretArn" -ForegroundColor Cyan
    
    # Import into Terraform
    terraform import module.secrets.aws_secretsmanager_secret.db_credentials $dbSecretArn
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ db_credentials imported successfully" -ForegroundColor Green
    } else {
        Write-Host "❌ Failed to import db_credentials" -ForegroundColor Red
    }
} else {
    Write-Host "⚠️  db_credentials does not exist in AWS" -ForegroundColor Yellow
}

 Write-Host "`nNext steps:" -ForegroundColor Yellow
 Write-Host "1. Run 'terraform plan' to verify the import" -ForegroundColor White
 Write-Host "2. Run 'terraform apply' to update any differences" -ForegroundColor White
 Write-Host "3. The secret VALUES are not imported, only the secret resource" -ForegroundColor White