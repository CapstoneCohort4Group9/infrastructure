# PowerShell script to setup AWS OIDC Provider and IAM Role for GitHub Actions
# This script is idempotent - can be run multiple times safely

param(
    [Parameter(Mandatory=$false)]
    [string]$AccountId = $null,

    [Parameter(Mandatory=$false)]
    [string]$GitHubOrg = "CapstoneCohort4Group9",  # Change this to your GitHub username or org
    
    [Parameter(Mandatory=$false)]
    [string]$GitHubRepo = "hopjetair",       # Change this to your repository name
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "us-east-1"
)

# Set AWS region
$env:AWS_DEFAULT_REGION = $Region

Write-Host "Setting up OIDC for GitHub Actions..." -ForegroundColor Green

# Get AWS Account ID
if ($AccountId) {
    Write-Host "Using provided Account ID: $AccountId" -ForegroundColor Yellow
} else {
    try {
        $AccountId = (aws sts get-caller-identity --query Account --output text).Trim()
        Write-Host "AWS Account ID (auto-detected): $AccountId" -ForegroundColor Yellow
    } catch {
        Write-Host "Error: Unable to get AWS account ID. Make sure AWS CLI is configured." -ForegroundColor Red
        Write-Host "You can also provide it manually: .\setup-aws-oidc.ps1 -AccountId 123456789012" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host "GitHub Org: $GitHubOrg" -ForegroundColor Yellow
Write-Host "GitHub Repo: $GitHubRepo" -ForegroundColor Yellow
Write-Host "AWS Region: $Region" -ForegroundColor Yellow

# Check if OIDC provider already exists
$oidcProviderArn = "arn:aws:iam::${AccountId}:oidc-provider/token.actions.githubusercontent.com"
$providerExists = $false

try {
    $null = aws iam get-open-id-connect-provider --open-id-connect-provider-arn $oidcProviderArn 2>&1
    if ($LASTEXITCODE -eq 0) {
        $providerExists = $true
        Write-Host "OIDC Provider already exists" -ForegroundColor Cyan
    }
} catch {
    Write-Host "OIDC Provider does not exist, will create..." -ForegroundColor Yellow
}

# Create OIDC Provider if it doesn't exist
if (-not $providerExists) {
    try {
        aws iam create-open-id-connect-provider `
            --url https://token.actions.githubusercontent.com `
            --client-id-list sts.amazonaws.com `
            --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 1c58a3a8518e8759bf075b76b750d4f2df264fcd
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "OIDC Provider created successfully" -ForegroundColor Green
        } else {
            throw "Failed to create OIDC Provider"
        }
    } catch {
        Write-Host "Error creating OIDC Provider: $_" -ForegroundColor Red
        exit 1
    }
}

# Create trust policy
$trustPolicy = @"
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::${AccountId}:oidc-provider/token.actions.githubusercontent.com"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
                },
                "StringLike": {
                    "token.actions.githubusercontent.com:sub": "repo:${GitHubOrg}/${GitHubRepo}:*"
                }
            }
        }
    ]
}
"@

# Save trust policy to temporary file
$trustPolicyFile = [System.IO.Path]::GetTempFileName()
Set-Content -Path $trustPolicyFile -Value $trustPolicy

# Check if role already exists
$roleExists = $false
try {
    $null = aws iam get-role --role-name GitHubActionsRole 2>&1
    if ($LASTEXITCODE -eq 0) {
        $roleExists = $true
        Write-Host "IAM Role already exists, updating trust policy..." -ForegroundColor Cyan
        
        # Update trust policy
        aws iam update-assume-role-policy `
            --role-name GitHubActionsRole `
            --policy-document file://$trustPolicyFile
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Trust policy updated" -ForegroundColor Green
        } else {
            Write-Host "Error updating trust policy" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "IAM Role does not exist, will create..." -ForegroundColor Yellow
}

# Create role if it doesn't exist
if (-not $roleExists) {
    try {
        aws iam create-role `
            --role-name GitHubActionsRole `
            --assume-role-policy-document file://$trustPolicyFile `
            --description "Role for GitHub Actions to deploy infrastructure"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "IAM Role created successfully" -ForegroundColor Green
        } else {
            throw "Failed to create IAM Role"
        }
    } catch {
        Write-Host "Error creating IAM Role: $_" -ForegroundColor Red
        Remove-Item $trustPolicyFile
        exit 1
    }
}

# Create IAM Policy
$iamPolicy = @"
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecr:*",
                "s3:ListBucket",
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
                "dynamodb:GetItem",
                "dynamodb:PutItem",
                "dynamodb:DeleteItem",
                "iam:GetRole",
                "iam:PassRole",
                "ec2:*",
                "rds:*"
            ],
            "Resource": "*"
        }
    ]
}
"@

# Save IAM policy to temporary file
$policyFile = [System.IO.Path]::GetTempFileName()
Set-Content -Path $policyFile -Value $iamPolicy

# Check if policy already exists
$policyArn = "arn:aws:iam::${AccountId}:policy/GitHubActionsPolicy"
$policyExists = $false

Write-Host "Checking if IAM Policy exists..." -ForegroundColor Yellow
try {
    $null = aws iam get-policy --policy-arn $policyArn 2>&1
    if ($LASTEXITCODE -eq 0) {
        $policyExists = $true
        Write-Host "IAM Policy already exists" -ForegroundColor Cyan
        
        # Create a new version of the policy to update it
        Write-Host "Updating policy with new version..." -ForegroundColor Yellow
        $null = aws iam create-policy-version `
            --policy-arn $policyArn `
            --policy-document file://$policyFile `
            --set-as-default 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Policy updated successfully" -ForegroundColor Green
        } else {
            Write-Host "Note: Policy update skipped (may have reached version limit)" -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "IAM Policy does not exist, will create..." -ForegroundColor Yellow
}

# Create policy if it doesn't exist
if (-not $policyExists) {
    try {
        Write-Host "Creating IAM Policy..." -ForegroundColor Yellow
        $createPolicyOutput = aws iam create-policy `
            --policy-name GitHubActionsPolicy `
            --policy-document file://$policyFile 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "IAM Policy created successfully" -ForegroundColor Green
        } else {
            throw "Failed to create policy: $createPolicyOutput"
        }
    } catch {
        Write-Host "Error creating IAM Policy: $_" -ForegroundColor Red
        Remove-Item $trustPolicyFile -ErrorAction SilentlyContinue
        Remove-Item $policyFile -ErrorAction SilentlyContinue
        exit 1
    }
}

# Attach policy to role
Write-Host "Attaching policy to role..." -ForegroundColor Yellow
try {
    # First check if policy is already attached
    $attachedPolicies = aws iam list-attached-role-policies --role-name GitHubActionsRole --query "AttachedPolicies[?PolicyArn=='$policyArn']" --output json | ConvertFrom-Json
    
    if ($attachedPolicies.Count -gt 0) {
        Write-Host "Policy is already attached to role" -ForegroundColor Cyan
    } else {
        $attachOutput = aws iam attach-role-policy `
            --role-name GitHubActionsRole `
            --policy-arn $policyArn 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Policy attached to role successfully" -ForegroundColor Green
        } else {
            throw "Failed to attach policy: $attachOutput"
        }
    }
} catch {
    Write-Host "Error attaching policy to role: $_" -ForegroundColor Red
    Write-Host "You may need to manually attach the policy to the role" -ForegroundColor Yellow
}

# Cleanup temporary files
Remove-Item $trustPolicyFile -ErrorAction SilentlyContinue
Remove-Item $policyFile -ErrorAction SilentlyContinue

Write-Host "`n✓ OIDC Setup Complete!" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Add these as repository variables in GitHub:" -ForegroundColor White
Write-Host "   - AWS_ACCOUNT_ID: $AccountId" -ForegroundColor Cyan
Write-Host "   - AWS_REGION: $Region" -ForegroundColor Cyan
Write-Host "`nIAM Role ARN: arn:aws:iam::${AccountId}:role/GitHubActionsRole" -ForegroundColor Green

# Verify the setup
Write-Host "`nVerifying setup..." -ForegroundColor Yellow
$roleInfo = aws iam get-role --role-name GitHubActionsRole --query Role --output json | ConvertFrom-Json
$attachedPolicies = aws iam list-attached-role-policies --role-name GitHubActionsRole --query AttachedPolicies --output json | ConvertFrom-Json

Write-Host "✓ Role exists: GitHubActionsRole" -ForegroundColor Green
Write-Host "✓ Trust policy configured for: repo:${GitHubOrg}/${GitHubRepo}:*" -ForegroundColor Green
if ($attachedPolicies | Where-Object { $_.PolicyName -eq "GitHubActionsPolicy" }) {
    Write-Host "✓ Policy attached: GitHubActionsPolicy" -ForegroundColor Green
} else {
    Write-Host "✗ Policy NOT attached: GitHubActionsPolicy" -ForegroundColor Red
    Write-Host "  Please manually attach the policy or re-run this script" -ForegroundColor Yellow
}