# PowerShell script to set all ECS service desired_count to 1
# This script will scale up all services in all clusters that are currently at 0 tasks

param(
    [Parameter(Mandatory=$false)]
    [string]$Region = "us-east-1",
    
    [Parameter(Mandatory=$false)]
    [string]$ClusterName = $null,  # If specified, only process this cluster
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf = $false,      # Dry run - show what would be changed without making changes
    
    [Parameter(Mandatory=$false)]
    [switch]$Force = $false        # Skip confirmation prompts
)

# Set AWS region
$env:AWS_DEFAULT_REGION = $Region

Write-Host "ECS Service Scale Up Script" -ForegroundColor Green
Write-Host "Region: $Region" -ForegroundColor Yellow
if ($WhatIf) {
    Write-Host "Mode: DRY RUN (no changes will be made)" -ForegroundColor Cyan
}

try {
    # Get all ECS clusters or specific cluster
    if ($ClusterName) {
        Write-Host "Processing specific cluster: $ClusterName" -ForegroundColor Yellow
        $clusters = @($ClusterName)
    } else {
        Write-Host "Getting all ECS clusters..." -ForegroundColor Yellow
        $clustersJson = aws ecs list-clusters --query "clusterArns" --output json
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to list ECS clusters"
        }
        $clusters = ($clustersJson | ConvertFrom-Json) | ForEach-Object { ($_ -split '/')[-1] }
    }

    if ($clusters.Count -eq 0) {
        Write-Host "No ECS clusters found" -ForegroundColor Yellow
        exit 0
    }

    Write-Host "Found $($clusters.Count) cluster(s)" -ForegroundColor Green

    $totalServices = 0
    $servicesToUpdate = @()

    # Collect all services across clusters
    foreach ($cluster in $clusters) {
        Write-Host "" 
        Write-Host "Processing cluster: $cluster" -ForegroundColor Cyan
        
        # Get all services in the cluster
        $servicesJson = aws ecs list-services --cluster $cluster --query "serviceArns" --output json
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Error listing services in cluster $cluster" -ForegroundColor Red
            continue
        }

        $services = ($servicesJson | ConvertFrom-Json) | ForEach-Object { ($_ -split '/')[-1] }
        
        if ($services.Count -eq 0) {
            Write-Host "  No services found in cluster $cluster" -ForegroundColor Yellow
            continue
        }

        Write-Host "  Found $($services.Count) service(s)" -ForegroundColor Green

        # Get detailed information for each service
        foreach ($service in $services) {
            $serviceDetailsJson = aws ecs describe-services --cluster $cluster --services $service --query "services[0]" --output json
            if ($LASTEXITCODE -ne 0) {
                Write-Host "  Error getting details for service $service" -ForegroundColor Red
                continue
            }

            $serviceDetails = $serviceDetailsJson | ConvertFrom-Json
            $currentDesiredCount = $serviceDetails.desiredCount
            $serviceName = $serviceDetails.serviceName
            $status = $serviceDetails.status

            Write-Host "    Service: $serviceName" -ForegroundColor White
            Write-Host "      Current desired count: $currentDesiredCount" -ForegroundColor Gray
            Write-Host "      Status: $status" -ForegroundColor Gray

            if ($status -eq "ACTIVE" -and $currentDesiredCount -eq 0) {
                $servicesToUpdate += @{
                    Cluster = $cluster
                    ServiceName = $serviceName
                    CurrentDesiredCount = $currentDesiredCount
                }
                $totalServices++
            } elseif ($currentDesiredCount -gt 0) {
                Write-Host "      Already running ($currentDesiredCount tasks) - skipping" -ForegroundColor Yellow
            } else {
                Write-Host "      Service not active - skipping" -ForegroundColor Yellow
            }
        }
    }

    if ($servicesToUpdate.Count -eq 0) {
        Write-Host ""
        Write-Host "No services need to be updated (all are already running or inactive)" -ForegroundColor Green
        exit 0
    }

    # Display summary
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "SUMMARY" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "Services to update: $($servicesToUpdate.Count)" -ForegroundColor Yellow

    foreach ($service in $servicesToUpdate) {
        Write-Host "  $($service.Cluster)/$($service.ServiceName) : $($service.CurrentDesiredCount) -> 1" -ForegroundColor White
    }

    if ($WhatIf) {
        Write-Host ""
        Write-Host "DRY RUN COMPLETE - No changes were made" -ForegroundColor Cyan
        exit 0
    }

    # Confirmation prompt
    if (-not $Force) {
        Write-Host ""
        Write-Host "This will scale up $($servicesToUpdate.Count) service(s) to 1 task each." -ForegroundColor Yellow
        $confirmation = Read-Host "Are you sure you want to continue? (y/N)"
        if ($confirmation -notmatch '^[Yy]$') {
            Write-Host "Operation cancelled" -ForegroundColor Yellow
            exit 0
        }
    }

    # Update services
    Write-Host ""
    Write-Host "Updating services..." -ForegroundColor Green
    $successCount = 0
    $errorCount = 0

    foreach ($service in $servicesToUpdate) {
        Write-Host "Updating $($service.Cluster)/$($service.ServiceName)..." -ForegroundColor White
        
        $updateResult = aws ecs update-service --cluster $service.Cluster --service $service.ServiceName --desired-count 1 --output json 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Success" -ForegroundColor Green
            $successCount++
        } else {
            Write-Host "  Failed: $updateResult" -ForegroundColor Red
            $errorCount++
        }
    }

    # Final summary
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "OPERATION COMPLETE" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "Successfully updated: $successCount service(s)" -ForegroundColor Green
    if ($errorCount -gt 0) {
        Write-Host "Failed updates: $errorCount service(s)" -ForegroundColor Red
    }

    if ($successCount -gt 0) {
        Write-Host ""
        Write-Host "Note: Services are being scaled up. It may take a few minutes for tasks to fully start." -ForegroundColor Yellow
        Write-Host "You can monitor progress with: aws ecs list-services --cluster CLUSTER-NAME" -ForegroundColor Cyan
    }

} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "Make sure AWS CLI is configured and you have the necessary ECS permissions." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Script completed." -ForegroundColor Green