# PowerShell script to update secret VALUES (not create secrets)
# Run this AFTER Terraform has created the secret resources

param(
    [Parameter(Mandatory=$false)]
    [string]$ApiKey = "my-secret-key",

    [Parameter(Mandatory=$false)]
    [string]$ApiSecret = "Capst0neo3@2024",

    [Parameter(Mandatory=$false)]
    [string]$DbUsername = "hopjetair",

    [Parameter(Mandatory=$false)]
    [string]$DbPassword = "SecurePass123!",

    [Parameter(Mandatory=$false)]
    [string]$Region = "us-east-1",
    
    [Parameter(Mandatory=$false)]
    [switch]$Force  # Force update even if deletion is pending
)

# Set AWS region
$env:AWS_DEFAULT_REGION = $Region

Write-Host "Updating secret values in AWS Secrets Manager..." -ForegroundColor Green

function Test-SecretExists {
    param([string]$SecretId)
    
    try {
        $secretInfo = aws secretsmanager describe-secret --secret-id $SecretId --region $Region 2>&1 | ConvertFrom-Json
        
        if ($LASTEXITCODE -eq 0) {
            # Check if marked for deletion
            if ($secretInfo.DeletedDate) {
                return @{
                    Exists = $true
                    Status = "SCHEDULED_FOR_DELETION"
                    DeletedDate = $secretInfo.DeletedDate
                    RecoveryWindow = $secretInfo.RecoveryWindowInDays
                }
            } else {
                return @{
                    Exists = $true
                    Status = "ACTIVE"
                }
            }
        }
    } catch {
        return @{
            Exists = $false
            Status = "NOT_FOUND"
        }
    }
    
    return @{
        Exists = $false
        Status = "NOT_FOUND"
    }
}

function Update-SecretValue {
    param(
        [string]$SecretId,
        [string]$SecretValue,
        [string]$Description
    )
    
    $secretStatus = Test-SecretExists -SecretId $SecretId
    
    if (-not $secretStatus.Exists) {
        Write-Host "❌ Secret '${SecretId}' does not exist!" -ForegroundColor Red
        Write-Host "   Please run Terraform first to create the secret resource." -ForegroundColor Yellow
        Write-Host "   Run: terraform apply" -ForegroundColor Cyan
        return $false
    }
    
    if ($secretStatus.Status -eq "SCHEDULED_FOR_DELETION") {
        Write-Host "⚠️  Secret '${SecretId}' is scheduled for deletion!" -ForegroundColor Yellow
        Write-Host "   Deleted Date: $($secretStatus.DeletedDate)" -ForegroundColor Yellow
        Write-Host "   Recovery Window: $($secretStatus.RecoveryWindow) days" -ForegroundColor Yellow
        
        if ($Force) {
            Write-Host "   Force flag set - attempting to restore and update..." -ForegroundColor Cyan
            
            # Restore the secret
            try {
                $null = aws secretsmanager restore-secret --secret-id $SecretId --region $Region 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "   ✅ Secret restored successfully" -ForegroundColor Green
                } else {
                    Write-Host "   ❌ Failed to restore secret" -ForegroundColor Red
                    return $false
                }
            } catch {
                Write-Host "   ❌ Error restoring secret: $_" -ForegroundColor Red
                return $false
            }
        } else {
            Write-Host "   Use -Force flag to restore and update the secret" -ForegroundColor Cyan
            Write-Host "   Or wait for deletion to complete and re-run Terraform" -ForegroundColor Cyan
            return $false
        }
    }
    
    # Update the secret value
    try {
        Write-Host "Updating ${SecretId}..." -ForegroundColor Cyan
        $updateResult = aws secretsmanager put-secret-value `
            --secret-id $SecretId `
            --secret-string $SecretValue `
            --region $Region 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ ${SecretId} updated successfully" -ForegroundColor Green
            
            # Parse and show version info
            $result = $updateResult | ConvertFrom-Json
            Write-Host "   Version: $($result.VersionId)" -ForegroundColor Gray
            return $true
        } else {
            Write-Host "❌ Failed to update ${SecretId}" -ForegroundColor Red
            Write-Host "   Error: ${updateResult}" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "❌ Error updating ${SecretId}: $_" -ForegroundColor Red
        return $false
    }
}

# Validate inputs
$hasApiSecrets = $ApiKey -or $ApiSecret
$hasDbSecrets = $DbUsername -or $DbPassword

if (-not $hasApiSecrets -and -not $hasDbSecrets) {
    Write-Host "No secret values provided. Use one or more parameters:" -ForegroundColor Yellow
    Write-Host "  -ApiKey 'your-key' -ApiSecret 'your-secret'" -ForegroundColor Cyan
    Write-Host "  -DbUsername 'username' -DbPassword 'password'" -ForegroundColor Cyan
    Write-Host "  -Force  (to restore secrets marked for deletion)" -ForegroundColor Cyan
    exit 1
}

$updateCount = 0
$errorCount = 0

# Update API secrets if provided
if ($hasApiSecrets) {
    # Get current values if only updating one field
    if ($ApiKey -and -not $ApiSecret) {
        try {
            $currentSecret = aws secretsmanager get-secret-value --secret-id api_secrets --query SecretString --output text | ConvertFrom-Json
            $ApiSecret = $currentSecret.api_secret
        } catch {
            Write-Host "Warning: Could not retrieve current api_secret value" -ForegroundColor Yellow
        }
    } elseif ($ApiSecret -and -not $ApiKey) {
        try {
            $currentSecret = aws secretsmanager get-secret-value --secret-id api_secrets --query SecretString --output text | ConvertFrom-Json
            $ApiKey = $currentSecret.api_key
        } catch {
            Write-Host "Warning: Could not retrieve current api_key value" -ForegroundColor Yellow
        }
    }
    
    $apiSecretValue = @{
        api_key = $ApiKey
        api_secret = $ApiSecret
    } | ConvertTo-Json -Compress
    
    if (Update-SecretValue -SecretId "api_secrets" -SecretValue $apiSecretValue -Description "API credentials") {
        $updateCount++
    } else {
        $errorCount++
    }
}

# Update DB credentials if provided
if ($hasDbSecrets) {
    # Get current values if only updating one field
    if ($DbUsername -and -not $DbPassword) {
        try {
            $currentSecret = aws secretsmanager get-secret-value --secret-id db_credentials --query SecretString --output text | ConvertFrom-Json
            $DbPassword = $currentSecret.password
        } catch {
            Write-Host "Warning: Could not retrieve current password value" -ForegroundColor Yellow
        }
    } elseif ($DbPassword -and -not $DbUsername) {
        try {
            $currentSecret = aws secretsmanager get-secret-value --secret-id db_credentials --query SecretString --output text | ConvertFrom-Json
            $DbUsername = $currentSecret.username
        } catch {
            Write-Host "Warning: Could not retrieve current username value" -ForegroundColor Yellow
        }
    }
    
    $dbSecretValue = @{
        username = $DbUsername
        password = $DbPassword
    } | ConvertTo-Json -Compress
    
    if (Update-SecretValue -SecretId "db_credentials" -SecretValue $dbSecretValue -Description "Database credentials") {
        $updateCount++
    } else {
        $errorCount++
    }
}

# Summary
Write-Host "`n📊 Summary:" -ForegroundColor Cyan
Write-Host "   Updated: $updateCount secrets" -ForegroundColor Green
if ($errorCount -gt 0) {
    Write-Host "   Errors: $errorCount secrets" -ForegroundColor Red
    exit 1
} else {
    Write-Host "`n✅ All secret values updated successfully!" -ForegroundColor Green
}

# Show how to retrieve secrets
Write-Host "`n📖 To retrieve secret values:" -ForegroundColor Cyan
Write-Host "   aws secretsmanager get-secret-value --secret-id api_secrets --query SecretString --output text | ConvertFrom-Json" -ForegroundColor Gray
Write-Host "   aws secretsmanager get-secret-value --secret-id db_credentials --query SecretString --output text | ConvertFrom-Json" -ForegroundColor Gray