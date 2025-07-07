# PowerShell script to setup S3 bucket and DynamoDB table for Terraform state
# This script is idempotent - can be run multiple times safely

param(
    [Parameter(Mandatory=$false)]
    [string]$AccountId = $null,

    [Parameter(Mandatory=$false)]
    [string]$Region = "ap-south-1"
)

# Set AWS region
$env:AWS_DEFAULT_REGION = $Region

Write-Host "Setting up Terraform backend..." -ForegroundColor Green

# Get AWS Account ID
if ($AccountId) {
    Write-Host "Using provided Account ID: $AccountId" -ForegroundColor Yellow
} else {
    try {
        $AccountId = (aws sts get-caller-identity --query Account --output text).Trim()
        Write-Host "AWS Account ID (auto-detected): $AccountId" -ForegroundColor Yellow
    } catch {
        Write-Host "Error: Unable to get AWS account ID. Make sure AWS CLI is configured." -ForegroundColor Red
        Write-Host "You can also provide it manually: .\setup-terraform-backend.ps1 -AccountId 123456789012" -ForegroundColor Yellow
        exit 1
    }
}

$bucketName = "terraform-state-bucket-$AccountId"
$tableName = "terraform-state-lock"

Write-Host "S3 Bucket: $bucketName" -ForegroundColor Yellow
Write-Host "DynamoDB Table: $tableName" -ForegroundColor Yellow
Write-Host "Region: $Region" -ForegroundColor Yellow

# Check if S3 bucket exists
$bucketExists = $false
Write-Host "`nChecking if S3 bucket exists..." -ForegroundColor Yellow
try {
    $null = aws s3api head-bucket --bucket $bucketName 2>&1
    if ($LASTEXITCODE -eq 0) {
        $bucketExists = $true
        Write-Host "S3 bucket already exists" -ForegroundColor Cyan
    }
} catch {
    Write-Host "S3 bucket does not exist, will create..." -ForegroundColor Yellow
}

# Create S3 bucket if it doesn't exist
if (-not $bucketExists) {
    try {
        Write-Host "Creating S3 bucket..." -ForegroundColor Yellow
        if ($Region -eq "us-east-1") {
            $null = aws s3api create-bucket --bucket $bucketName --region $Region 2>&1
        } else {
            $null = aws s3api create-bucket `
                --bucket $bucketName `
                --region $Region `
                --create-bucket-configuration LocationConstraint=$Region 2>&1
        }
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create bucket"
        }
        Write-Host "S3 bucket created successfully" -ForegroundColor Green
        
        # Enable versioning
        Write-Host "Enabling versioning..." -ForegroundColor Yellow
        $null = aws s3api put-bucket-versioning `
            --bucket $bucketName `
            --versioning-configuration Status=Enabled 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Versioning enabled" -ForegroundColor Green
        }
        
        # Enable encryption
        Write-Host "Enabling encryption..." -ForegroundColor Yellow
        $encryptionConfig = @"
{
    "Rules": [{
        "ApplyServerSideEncryptionByDefault": {
            "SSEAlgorithm": "AES256"
        }
    }]
}
"@
        $encryptionFile = [System.IO.Path]::GetTempFileName()
        Set-Content -Path $encryptionFile -Value $encryptionConfig
        
        $null = aws s3api put-bucket-encryption `
            --bucket $bucketName `
            --server-side-encryption-configuration file://$encryptionFile 2>&1
        
        Remove-Item $encryptionFile
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Encryption enabled" -ForegroundColor Green
        }
        
        # Block public access
        Write-Host "Blocking public access..." -ForegroundColor Yellow
        $null = aws s3api put-public-access-block `
            --bucket $bucketName `
            --public-access-block-configuration `
            "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Public access blocked" -ForegroundColor Green
        }
        
        # Add lifecycle policy for old state file versions
        Write-Host "Adding lifecycle policy for cost optimization..." -ForegroundColor Yellow
        $lifecycleConfig = @"
{
    "Rules": [
        {
            "ID": "DeleteOldStateVersions",
            "Status": "Enabled",
            "NoncurrentVersionExpiration": {
                "NoncurrentDays": 30
            },
            "AbortIncompleteMultipartUpload": {
                "DaysAfterInitiation": 7
            },
            "Filter": {
                "Prefix": ""
            }
        },
        {
            "ID": "TransitionOldVersionsToIA",
            "Status": "Enabled",
            "NoncurrentVersionTransitions": [
                {
                    "NoncurrentDays": 7,
                    "StorageClass": "STANDARD_IA"
                }
            ],
            "Filter": {
                "Prefix": ""
            }
        }
    ]
}
"@
        $lifecycleFile = [System.IO.Path]::GetTempFileName()
        Set-Content -Path $lifecycleFile -Value $lifecycleConfig
        
        $null = aws s3api put-bucket-lifecycle-configuration `
            --bucket $bucketName `
            --lifecycle-configuration file://$lifecycleFile 2>&1
        
        Remove-Item $lifecycleFile
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Lifecycle policy added (old versions will be transitioned to IA after 7 days, deleted after 30 days)" -ForegroundColor Green
        }
        
    } catch {
        Write-Host "Error creating/configuring S3 bucket: $_" -ForegroundColor Red
        exit 1
    }
} else {
    # Bucket exists, verify configuration
    Write-Host "Verifying bucket configuration..." -ForegroundColor Yellow
    
    # Check versioning
    $versioningStatus = aws s3api get-bucket-versioning --bucket $bucketName --query Status --output text 2>&1
    if ($versioningStatus -eq "Enabled") {
        Write-Host "✓ Versioning is enabled" -ForegroundColor Green
    } else {
        Write-Host "✗ Versioning is not enabled - enabling now..." -ForegroundColor Yellow
        aws s3api put-bucket-versioning --bucket $bucketName --versioning-configuration Status=Enabled
    }
    
    # Check encryption
    $null = aws s3api get-bucket-encryption --bucket $bucketName 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Encryption is enabled" -ForegroundColor Green
    } else {
        Write-Host "✗ Encryption is not enabled - enabling now..." -ForegroundColor Yellow
        $encryptionConfig = @"
{
    "Rules": [{
        "ApplyServerSideEncryptionByDefault": {
            "SSEAlgorithm": "AES256"
        }
    }]
}
"@
        $encryptionFile = [System.IO.Path]::GetTempFileName()
        Set-Content -Path $encryptionFile -Value $encryptionConfig
        aws s3api put-bucket-encryption --bucket $bucketName --server-side-encryption-configuration file://$encryptionFile
        Remove-Item $encryptionFile
    }
}

# Check if DynamoDB table exists
$tableExists = $false
Write-Host "`nChecking if DynamoDB table exists..." -ForegroundColor Yellow
try {
    $null = aws dynamodb describe-table --table-name $tableName --region $Region 2>&1
    if ($LASTEXITCODE -eq 0) {
        $tableExists = $true
        Write-Host "DynamoDB table already exists" -ForegroundColor Cyan
    }
} catch {
    Write-Host "DynamoDB table does not exist, will create..." -ForegroundColor Yellow
}

# Create DynamoDB table if it doesn't exist
if (-not $tableExists) {
    try {
        Write-Host "Creating DynamoDB table..." -ForegroundColor Yellow
        $null = aws dynamodb create-table `
            --table-name $tableName `
            --attribute-definitions AttributeName=LockID,AttributeType=S `
            --key-schema AttributeName=LockID,KeyType=HASH `
            --billing-mode PAY_PER_REQUEST `
            --region $Region `
            --tags Key=Purpose,Value=TerraformStateLock Key=ManagedBy,Value=Terraform 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create DynamoDB table"
        }
        
        Write-Host "Waiting for table to be created..." -ForegroundColor Yellow
        aws dynamodb wait table-exists --table-name $tableName --region $Region
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "DynamoDB table created successfully" -ForegroundColor Green
        }
    } catch {
        Write-Host "Error creating DynamoDB table: $_" -ForegroundColor Red
        exit 1
    }
} else {
    # Table exists, check its status
    $tableStatus = aws dynamodb describe-table --table-name $tableName --query Table.TableStatus --output text
    Write-Host "✓ Table status: $tableStatus" -ForegroundColor Green
}

Write-Host "`n✅ Terraform backend setup complete!" -ForegroundColor Green
Write-Host "`nBackend configuration for your Terraform files:" -ForegroundColor Yellow
Write-Host @"
  
  backend "s3" {
    bucket         = "$bucketName"
    key            = "terraform.tfstate"
    region         = "$Region"
    dynamodb_table = "$tableName"
    encrypt        = true
  }
"@ -ForegroundColor Cyan

Write-Host "`nCost optimization notes:" -ForegroundColor Yellow
Write-Host "- Old state versions will transition to Infrequent Access storage after 7 days" -ForegroundColor White
Write-Host "- Old state versions will be deleted after 30 days" -ForegroundColor White
Write-Host "- DynamoDB is using on-demand billing (pay per request)" -ForegroundColor White

# If you want to add the ECR lifecycle policy you mentioned, here's a separate script for that
Write-Host "`nNote: To set up ECR repositories with lifecycle policies, use Terraform with the configuration provided in the main setup." -ForegroundColor Yellow