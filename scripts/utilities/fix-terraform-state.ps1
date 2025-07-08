# PowerShell script to fix Terraform state issues with secrets

param(
    [Parameter(Mandatory=$false)]
    [string]$Action = "check"  # check, remove, or refresh
)

Write-Host "Terraform State Management for Secrets" -ForegroundColor Green

# Check current state
if ($Action -eq "check" -or $Action -eq "all") {
    Write-Host "`nChecking current Terraform state..." -ForegroundColor Yellow
    
    # List all resources in state
    Write-Host "`nResources in Terraform state:" -ForegroundColor Cyan
    terraform state list | Where-Object { $_ -like "*secret*" }
    
    # Show detailed info about secrets
    Write-Host "`nDetailed state of secrets:" -ForegroundColor Cyan
    terraform state show module.secrets.aws_secretsmanager_secret.api_secrets 2>$null
    terraform state show module.secrets.aws_secretsmanager_secret.db_credentials 2>$null
    
    Write-Host "`nTo remove these from state, run: .\fix-terraform-state.ps1 -Action remove" -ForegroundColor Yellow
    Write-Host "To refresh state from AWS, run: .\fix-terraform-state.ps1 -Action refresh" -ForegroundColor Yellow
}

# Remove from state
if ($Action -eq "remove") {
    Write-Host "`nRemoving secrets from Terraform state..." -ForegroundColor Yellow
    Write-Host "This will NOT delete the actual secrets in AWS" -ForegroundColor Cyan
    
    # Remove api_secrets
    Write-Host "`nRemoving api_secrets from state..." -ForegroundColor Yellow
    terraform state rm module.secrets.aws_secretsmanager_secret.api_secrets
    
    # Remove db_credentials
    Write-Host "`nRemoving db_credentials from state..." -ForegroundColor Yellow
    terraform state rm module.secrets.aws_secretsmanager_secret.db_credentials
    
    Write-Host "`n✅ Secrets removed from state" -ForegroundColor Green
    Write-Host "Now you can run the import script again" -ForegroundColor Yellow
}

# Refresh state from AWS
if ($Action -eq "refresh") {
    Write-Host "`nRefreshing Terraform state from AWS..." -ForegroundColor Yellow
    Write-Host "This will update the state to match what's actually in AWS" -ForegroundColor Cyan
    
    terraform refresh
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n✅ State refreshed successfully" -ForegroundColor Green
        Write-Host "Now run: terraform plan" -ForegroundColor Yellow
    } else {
        Write-Host "`n❌ Refresh failed" -ForegroundColor Red
    }
}