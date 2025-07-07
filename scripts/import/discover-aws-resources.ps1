# Simple AWS Resource Discovery Script

param(
    [Parameter(Mandatory=$false)]
    [string[]]$Regions = @("ap-southeast-2")
)

Write-Host "AWS Resource Discovery Tool" -ForegroundColor Green
Write-Host "Regions to check: $($Regions -join ', ')" -ForegroundColor Yellow

# Initialize results
$allResources = @{}

# Discover IAM Resources (Global)
Write-Host "`nDiscovering IAM Resources (Global)..." -ForegroundColor Cyan

# Get IAM Roles
Write-Host "  Checking IAM Roles..." -ForegroundColor Yellow
$roles = aws iam list-roles --output json | ConvertFrom-Json
$customRoles = @()
foreach ($role in $roles.Roles) {
    if (-not $role.RoleName.StartsWith("AWS") -and -not $role.RoleName.Contains("aws-service-role")) {
        $customRoles += @{
            Name = $role.RoleName
            Arn = $role.Arn
            CreateDate = $role.CreateDate
        }
        Write-Host "    Found: $($role.RoleName)" -ForegroundColor Gray
    }
}

# Get IAM Policies
Write-Host "  Checking IAM Policies..." -ForegroundColor Yellow
$policies = aws iam list-policies --scope Local --output json | ConvertFrom-Json
$customPolicies = @()
foreach ($policy in $policies.Policies) {
    $customPolicies += @{
        Name = $policy.PolicyName
        Arn = $policy.Arn
    }
    Write-Host "    Found: $($policy.PolicyName)" -ForegroundColor Gray
}

$allResources["global"] = @{
    Roles = $customRoles
    Policies = $customPolicies
}

# Discover Regional Resources
foreach ($region in $Regions) {
    Write-Host "`nDiscovering Resources in $region..." -ForegroundColor Cyan
    $env:AWS_DEFAULT_REGION = $region
    
    $regionResources = @{
        EC2Instances = @()
        VPCs = @()
        SecurityGroups = @()
        RDSInstances = @()
        S3Buckets = @()
    }
    
    # EC2 Instances
    Write-Host "  Checking EC2 Instances..." -ForegroundColor Yellow
    try {
        $instances = aws ec2 describe-instances --query "Reservations[].Instances[?State.Name!='terminated']" --output json 2>$null | ConvertFrom-Json
        if ($instances) {
            foreach ($instance in $instances) {
                $name = ($instance.Tags | Where-Object { $_.Key -eq "Name" }).Value
                if (-not $name) { $name = "Unnamed" }
                $regionResources.EC2Instances += @{
                    InstanceId = $instance.InstanceId
                    Name = $name
                    Type = $instance.InstanceType
                    State = $instance.State.Name
                }
                Write-Host "    Found: $($instance.InstanceId) - $name" -ForegroundColor Gray
            }
        } else {
            Write-Host "    No EC2 instances found" -ForegroundColor DarkGray
        }
    } catch {
        Write-Host "    No EC2 instances found" -ForegroundColor DarkGray
    }
    
    # VPCs
    Write-Host "  Checking VPCs..." -ForegroundColor Yellow
    try {
        $vpcs = aws ec2 describe-vpcs --output json 2>$null | ConvertFrom-Json
        if ($vpcs.Vpcs) {
            foreach ($vpc in $vpcs.Vpcs) {
                if (-not $vpc.IsDefault) {
                    $name = ($vpc.Tags | Where-Object { $_.Key -eq "Name" }).Value
                    if (-not $name) { $name = "Unnamed" }
                    $regionResources.VPCs += @{
                        VpcId = $vpc.VpcId
                        Name = $name
                        CidrBlock = $vpc.CidrBlock
                    }
                    Write-Host "    Found: $($vpc.VpcId) - $name" -ForegroundColor Gray
                }
            }
        }
    } catch {
        Write-Host "    No custom VPCs found" -ForegroundColor DarkGray
    }
    
    # RDS Instances
    Write-Host "  Checking RDS Instances..." -ForegroundColor Yellow
    try {
        $rdsResult = aws rds describe-db-instances --output json 2>$null | ConvertFrom-Json
        if ($rdsResult.DBInstances) {
            foreach ($db in $rdsResult.DBInstances) {
                $regionResources.RDSInstances += @{
                    DBInstanceId = $db.DBInstanceIdentifier
                    Engine = $db.Engine
                    Class = $db.DBInstanceClass
                    Status = $db.DBInstanceStatus
                }
                Write-Host "    Found: $($db.DBInstanceIdentifier)" -ForegroundColor Gray
            }
        } else {
            Write-Host "    No RDS instances found" -ForegroundColor DarkGray
        }
    } catch {
        Write-Host "    No RDS instances found" -ForegroundColor DarkGray
    }
    
    $allResources[$region] = $regionResources
}

# Save results
Write-Host "`nSaving results..." -ForegroundColor Yellow
$allResources | ConvertTo-Json -Depth 10 | Set-Content "discovered-resources.json"

# Display summary
Write-Host "`n=== Discovery Summary ===" -ForegroundColor Green
Write-Host "`nGlobal Resources:" -ForegroundColor Cyan
Write-Host "  IAM Roles: $($allResources.global.Roles.Count)" -ForegroundColor White
Write-Host "  IAM Policies: $($allResources.global.Policies.Count)" -ForegroundColor White

foreach ($region in $Regions) {
    Write-Host "`n$region Resources:" -ForegroundColor Cyan
    $r = $allResources[$region]
    Write-Host "  EC2 Instances: $($r.EC2Instances.Count)" -ForegroundColor White
    Write-Host "  VPCs: $($r.VPCs.Count)" -ForegroundColor White
    Write-Host "  RDS Instances: $($r.RDSInstances.Count)" -ForegroundColor White
}

Write-Host "`nResults saved to: discovered-resources.json" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Review discovered-resources.json" -ForegroundColor White
Write-Host "2. Create Terraform configurations for resources you want to import" -ForegroundColor White
Write-Host "3. Run terraform import commands" -ForegroundColor White