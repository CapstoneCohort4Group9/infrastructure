# PowerShell script to help import existing AWS resources into Terraform

param(
    [Parameter(Mandatory=$false)]
    [string]$Action = "discover",  # discover, generate, import
    
    [Parameter(Mandatory=$false)]
    [string[]]$Regions = @("ap-southeast-2"),  # Add your regions
    
    [Parameter(Mandatory=$false)]
    [string[]]$ResourceTypes = @("iam", "ec2", "rds", "s3", "vpc","ecs")
)

Write-Host "AWS Resource Discovery and Import Tool" -ForegroundColor Green

# Function to discover IAM resources (global)
function Get-IAMResources {
    Write-Host "`n🌍 Discovering IAM Resources (Global)..." -ForegroundColor Cyan
    
    $resources = @{
        Roles = @()
        Policies = @()
        Users = @()
        Groups = @()
    }
    
    # Get IAM Roles
    Write-Host "  Checking IAM Roles..." -ForegroundColor Yellow
    $roles = aws iam list-roles --query "Roles[?contains(Path, '/') && !contains(RoleName, 'aws-service-role')]" --output json | ConvertFrom-Json
    foreach ($role in $roles) {
        if (-not $role.RoleName.StartsWith("AWS")) {
            $resources.Roles += @{
                Name = $role.RoleName
                Arn = $role.Arn
                Path = $role.Path
            }
            Write-Host "    ✓ Role: $($role.RoleName)" -ForegroundColor Gray
        }
    }
    
    # Get Customer Managed Policies
    Write-Host "  Checking IAM Policies..." -ForegroundColor Yellow
    $policies = aws iam list-policies --scope Local --output json | ConvertFrom-Json
    foreach ($policy in $policies.Policies) {
        $resources.Policies += @{
            Name = $policy.PolicyName
            Arn = $policy.Arn
        }
        Write-Host "    ✓ Policy: $($policy.PolicyName)" -ForegroundColor Gray
    }
    
    return $resources
}

# Function to discover regional resources
function Get-RegionalResources {
    param([string]$Region)
    
    Write-Host "`n🌎 Discovering Resources in $Region..." -ForegroundColor Cyan
    $env:AWS_DEFAULT_REGION = $Region
    
    $resources = @{
        EC2Instances = @()
        SecurityGroups = @()
        VPCs = @()
        RDSInstances = @()
        S3Buckets = @()
        ECRRepos = @()
    }
    
    # EC2 Instances
    if ($ResourceTypes -contains "ec2") {
        Write-Host "  Checking EC2 Instances..." -ForegroundColor Yellow
        $instances = aws ec2 describe-instances --query "Reservations[].Instances[?State.Name!='terminated']" --output json | ConvertFrom-Json
        foreach ($instance in $instances) {
            $name = ($instance.Tags | Where-Object { $_.Key -eq "Name" }).Value
            $resources.EC2Instances += @{
                InstanceId = $instance.InstanceId
                Name = $name
                State = $instance.State.Name
                Type = $instance.InstanceType
            }
            Write-Host "    ✓ Instance: $($instance.InstanceId) ($name)" -ForegroundColor Gray
        }
    }
    
    # VPCs
    if ($ResourceTypes -contains "vpc") {
        Write-Host "  Checking VPCs..." -ForegroundColor Yellow
        $vpcs = aws ec2 describe-vpcs --query "Vpcs[?!IsDefault]" --output json | ConvertFrom-Json
        foreach ($vpc in $vpcs) {
            $name = ($vpc.Tags | Where-Object { $_.Key -eq "Name" }).Value
            $resources.VPCs += @{
                VpcId = $vpc.VpcId
                Name = $name
                CidrBlock = $vpc.CidrBlock
            }
            Write-Host "    ✓ VPC: $($vpc.VpcId) ($name)" -ForegroundColor Gray
        }
    }
    
    # RDS Instances
    if ($ResourceTypes -contains "rds") {
        Write-Host "  Checking RDS Instances..." -ForegroundColor Yellow
        try {
            $dbInstances = aws rds describe-db-instances --output json | ConvertFrom-Json
            foreach ($db in $dbInstances.DBInstances) {
                $resources.RDSInstances += @{
                    DBInstanceIdentifier = $db.DBInstanceIdentifier
                    Engine = $db.Engine
                    Status = $db.DBInstanceStatus
                }
                Write-Host "    ✓ RDS: $($db.DBInstanceIdentifier)" -ForegroundColor Gray
            }
        } catch {
            Write-Host "    No RDS instances found" -ForegroundColor DarkGray
        }
    }
    
    return $resources
}

# Function to generate Terraform configuration
function New-TerraformConfig {
    param($Resources, $Region = "global")
    
    $config = @"
# Auto-generated Terraform configuration for existing resources
# Region: $Region
# Generated: $(Get-Date)

"@
    
    # Generate IAM Role configurations
    if ($Resources.Roles) {
        foreach ($role in $Resources.Roles) {
            $config += @"

# Import with: terraform import aws_iam_role.$($role.Name -replace '[^a-zA-Z0-9]', '_') $($role.Name)
resource "aws_iam_role" "$($role.Name -replace '[^a-zA-Z0-9]', '_')" {
  name = "$($role.Name)"
  path = "$($role.Path)"
  
  # You'll need to add the assume_role_policy after import
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = []  # TODO: Add actual policy
  })
  
  tags = {
    ManagedBy = "terraform"
    ImportedOn = "$(Get-Date -Format 'yyyy-MM-dd')"
  }
}

"@
        }
    }
    
    # Generate EC2 Instance configurations
    if ($Resources.EC2Instances) {
        foreach ($instance in $Resources.EC2Instances) {
            $config += @"

# Import with: terraform import aws_instance.$($instance.Name -replace '[^a-zA-Z0-9]', '_') $($instance.InstanceId)
resource "aws_instance" "$($instance.Name -replace '[^a-zA-Z0-9]', '_')" {
  # Basic configuration - update after import
  instance_type = "$($instance.Type)"
  
  tags = {
    Name = "$($instance.Name)"
    ManagedBy = "terraform"
  }
}

"@
        }
    }
    
    return $config
}

# Main execution
switch ($Action) {
    "discover" {
        $allResources = @{}
        
        # Get IAM resources (global)
        if ($ResourceTypes -contains "iam") {
            $allResources["global"] = Get-IAMResources
        }
        
        # Get regional resources
        foreach ($region in $Regions) {
            $allResources[$region] = Get-RegionalResources -Region $region
        }
        
        # Save discovery results
        $allResources | ConvertTo-Json -Depth 10 | Set-Content "discovered-resources.json"
        Write-Host "`n✅ Discovery complete! Results saved to discovered-resources.json" -ForegroundColor Green
        
        # Summary
        Write-Host "`n📊 Summary:" -ForegroundColor Cyan
        foreach ($region in $allResources.Keys) {
            Write-Host "`n  $region`:" -ForegroundColor Yellow
            $resources = $allResources[$region]
            foreach ($type in $resources.Keys) {
                if ($resources[$type].Count -gt 0) {
                    Write-Host "    - $type`: $($resources[$type].Count)" -ForegroundColor White
                }
            }
        }
    }
    
    "generate" {
        # Load discovered resources
        if (Test-Path "discovered-resources.json") {
            $allResources = Get-Content "discovered-resources.json" | ConvertFrom-Json
            
            # Generate Terraform files
            foreach ($region in $Regions) {
                if ($allResources.$region) {
                    $config = New-TerraformConfig -Resources $allResources.$region -Region $region
                    $filename = "import-$region.tf"
                    $config | Set-Content $filename
                    Write-Host "✅ Generated $filename" -ForegroundColor Green
                }
            }
            
            # Generate global resources (IAM)
            if ($allResources.global) {
                $config = New-TerraformConfig -Resources $allResources.global -Region "global"
                $config | Set-Content "import-iam.tf"
                Write-Host "✅ Generated import-iam.tf" -ForegroundColor Green
            }
            
            # Generate import commands
            $importCommands = @"
# Terraform Import Commands
# Run these after adding the generated .tf files to your Terraform configuration

"@
            # Add import commands based on discovered resources
            $importCommands | Set-Content "import-commands.sh"
            Write-Host "✅ Generated import-commands.sh" -ForegroundColor Green
            
        } else {
            Write-Host "❌ No discovered resources found. Run with -Action discover first" -ForegroundColor Red
        }
    }
    
    "import" {
        Write-Host "Import process guidance:" -ForegroundColor Yellow
        Write-Host "1. Run discovery: .\import-existing-aws-resources.ps1 -Action discover" -ForegroundColor White
        Write-Host "2. Generate configs: .\import-existing-aws-resources.ps1 -Action generate" -ForegroundColor White
        Write-Host "3. Review and edit the generated .tf files" -ForegroundColor White
        Write-Host "4. Run the import commands from import-commands.sh" -ForegroundColor White
    }
}