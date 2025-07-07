# Generate Terraform Import Commands from discovered resources

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceFile = "discovered-resources.json",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputDir = "terraform-import"
)

if (-not (Test-Path $ResourceFile)) {
    Write-Host "Error: Resource file not found. Run discover-all-aws-resources.ps1 first." -ForegroundColor Red
    exit 1
}

Write-Host "Generating Terraform Import Configuration" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Gray

# Create output directory
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

# Load discovered resources
$resources = Get-Content $ResourceFile | ConvertFrom-Json

# Generate provider configuration
$providerConfig = @"
# Provider configuration for discovered resources
# Generated on: $(Get-Date)

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

"@

# Add providers for each region
foreach ($region in $resources.PSObject.Properties.Name | Where-Object { $_ -ne "global" }) {
    $providerConfig += @"

provider "aws" {
  alias  = "$($region -replace '-', '_')"
  region = "$region"
}
"@
}

$providerConfig | Set-Content "$OutputDir\providers.tf"

# Generate import commands
$importCommands = @"
#!/bin/bash
# Terraform Import Commands
# Generated on: $(Get-Date)
# 
# Usage: Run these commands after creating the corresponding Terraform resources

"@

# Process each region
foreach ($region in $resources.PSObject.Properties.Name | Where-Object { $_ -ne "global" }) {
    $regionResources = $resources.$region
    $regionAlias = $region -replace '-', '_'
    
    Write-Host "`nGenerating configs for $region" -ForegroundColor Cyan
    
    # Create region-specific terraform file
    $terraformConfig = @"
# Resources for $region
# Generated on: $(Get-Date)

"@
    
    # VPCs
    if ($regionResources.VPCs.Count -gt 0) {
        $terraformConfig += "`n# VPCs`n"
        $importCommands += "`n# VPCs in $region`n"
        
        foreach ($vpc in $regionResources.VPCs) {
            if (-not $vpc.IsDefault) {
                $resourceName = "vpc_$($vpc.Name -replace '[^a-zA-Z0-9]', '_')"
                if (-not $resourceName -or $resourceName -eq "vpc_") { $resourceName = "vpc_$($vpc.VpcId -replace '-', '_')" }
                
                $terraformConfig += @"
resource "aws_vpc" "$resourceName" {
  provider = aws.$regionAlias
  
  cidr_block = "$($vpc.CidrBlock)"
  
  tags = {
    Name = "$($vpc.Name)"
  }
}

"@
                $importCommands += "terraform import 'aws_vpc.$resourceName' $($vpc.VpcId)`n"
            }
        }
    }
    
    # Subnets
    if ($regionResources.Subnets.Count -gt 0) {
        $terraformConfig += "`n# Subnets`n"
        $importCommands += "`n# Subnets in $region`n"
        
        foreach ($subnet in $regionResources.Subnets) {
            $resourceName = "subnet_$($subnet.Name -replace '[^a-zA-Z0-9]', '_')"
            if (-not $resourceName -or $resourceName -eq "subnet_") { $resourceName = "subnet_$($subnet.SubnetId -replace '-', '_')" }
            
            $terraformConfig += @"
resource "aws_subnet" "$resourceName" {
  provider = aws.$regionAlias
  
  vpc_id            = "$($subnet.VpcId)"  # Update with vpc reference
  cidr_block        = "$($subnet.CidrBlock)"
  availability_zone = "$($subnet.AvailabilityZone)"
  
  tags = {
    Name = "$($subnet.Name)"
    Type = "$($subnet.Type)"
  }
}

"@
            $importCommands += "terraform import 'aws_subnet.$resourceName' $($subnet.SubnetId)`n"
        }
    }
    
    # Security Groups
    if ($regionResources.SecurityGroups.Count -gt 0) {
        $terraformConfig += "`n# Security Groups`n"
        $importCommands += "`n# Security Groups in $region`n"
        
        foreach ($sg in $regionResources.SecurityGroups) {
            $resourceName = "sg_$($sg.GroupName -replace '[^a-zA-Z0-9]', '_')"
            
            $terraformConfig += @"
resource "aws_security_group" "$resourceName" {
  provider = aws.$regionAlias
  
  name        = "$($sg.GroupName)"
  description = "$($sg.Description)"
  vpc_id      = "$($sg.VpcId)"  # Update with vpc reference
  
  # Ingress and egress rules will be imported
  
  tags = {
    Name = "$($sg.GroupName)"
  }
}

"@
            $importCommands += "terraform import 'aws_security_group.$resourceName' $($sg.GroupId)`n"
        }
    }
    
    # Internet Gateways
    if ($regionResources.InternetGateways.Count -gt 0) {
        $terraformConfig += "`n# Internet Gateways`n"
        $importCommands += "`n# Internet Gateways in $region`n"
        
        foreach ($igw in $regionResources.InternetGateways) {
            $resourceName = "igw_$($igw.Name -replace '[^a-zA-Z0-9]', '_')"
            if (-not $resourceName -or $resourceName -eq "igw_") { $resourceName = "igw_$($igw.InternetGatewayId -replace '-', '_')" }
            
            $terraformConfig += @"
resource "aws_internet_gateway" "$resourceName" {
  provider = aws.$regionAlias
  
  vpc_id = "$($igw.AttachedVpcId)"  # Update with vpc reference
  
  tags = {
    Name = "$($igw.Name)"
  }
}

"@
            $importCommands += "terraform import 'aws_internet_gateway.$resourceName' $($igw.InternetGatewayId)`n"
        }
    }
    
    # ECS Clusters
    if ($regionResources.ECSClusters.Count -gt 0) {
        $terraformConfig += "`n# ECS Clusters`n"
        $importCommands += "`n# ECS Clusters in $region`n"
        
        foreach ($cluster in $regionResources.ECSClusters) {
            $resourceName = "ecs_cluster_$($cluster.ClusterName -replace '[^a-zA-Z0-9]', '_')"
            
            $terraformConfig += @"
resource "aws_ecs_cluster" "$resourceName" {
  provider = aws.$regionAlias
  
  name = "$($cluster.ClusterName)"
  
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  
  tags = {
    Name = "$($cluster.ClusterName)"
  }
}

"@
            $importCommands += "terraform import 'aws_ecs_cluster.$resourceName' $($cluster.ClusterName)`n"
        }
    }
    
    # ECS Services
    if ($regionResources.ECSServices.Count -gt 0) {
        $terraformConfig += "`n# ECS Services`n"
        $importCommands += "`n# ECS Services in $region`n"
        
        foreach ($service in $regionResources.ECSServices) {
            $clusterName = ($service.ClusterArn -split '/')[-1]
            $resourceName = "ecs_service_$($service.ServiceName -replace '[^a-zA-Z0-9]', '_')"
            
            $terraformConfig += @"
resource "aws_ecs_service" "$resourceName" {
  provider = aws.$regionAlias
  
  name            = "$($service.ServiceName)"
  cluster         = "$clusterName"  # Update with cluster reference
  task_definition = "$($service.TaskDefinition -split '/' | Select-Object -Last 1)"
  desired_count   = $($service.DesiredCount)
  launch_type     = "$($service.LaunchType)"
  
  # Additional configuration will be imported
}

"@
            $importCommands += "terraform import 'aws_ecs_service.$resourceName' $clusterName/$($service.ServiceName)`n"
        }
    }
    
    # Application Load Balancers
    if ($regionResources.ALBs.Count -gt 0) {
        $terraformConfig += "`n# Application Load Balancers`n"
        $importCommands += "`n# Application Load Balancers in $region`n"
        
        foreach ($alb in $regionResources.ALBs) {
            $resourceName = "alb_$($alb.LoadBalancerName -replace '[^a-zA-Z0-9]', '_')"
            
            $terraformConfig += @"
resource "aws_lb" "$resourceName" {
  provider = aws.$regionAlias
  
  name               = "$($alb.LoadBalancerName)"
  load_balancer_type = "application"
  scheme             = "$($alb.Scheme)"
  
  # Subnets and security groups will be imported
  
  tags = {
    Name = "$($alb.LoadBalancerName)"
  }
}

"@
            $importCommands += "terraform import 'aws_lb.$resourceName' $($alb.LoadBalancerArn)`n"
        }
    }
    
    # Target Groups
    if ($regionResources.TargetGroups.Count -gt 0) {
        $terraformConfig += "`n# Target Groups`n"
        $importCommands += "`n# Target Groups in $region`n"
        
        foreach ($tg in $regionResources.TargetGroups) {
            $resourceName = "tg_$($tg.TargetGroupName -replace '[^a-zA-Z0-9]', '_')"
            
            $terraformConfig += @"
resource "aws_lb_target_group" "$resourceName" {
  provider = aws.$regionAlias
  
  name        = "$($tg.TargetGroupName)"
  port        = $($tg.Port)
  protocol    = "$($tg.Protocol)"
  target_type = "$($tg.TargetType)"
  vpc_id      = "$($tg.VpcId)"  # Update with vpc reference
  
  health_check {
    path = "$($tg.HealthCheckPath)"
  }
  
  tags = {
    Name = "$($tg.TargetGroupName)"
  }
}

"@
            $importCommands += "terraform import 'aws_lb_target_group.$resourceName' $($tg.TargetGroupArn)`n"
        }
    }
    
    # Route Tables
    if ($regionResources.RouteTables.Count -gt 0) {
        $terraformConfig += "`n# Route Tables`n"
        $importCommands += "`n# Route Tables in $region`n"
        
        foreach ($rt in $regionResources.RouteTables) {
            if (-not $rt.IsMain) {  # Skip main route tables
                $resourceName = "rt_$($rt.Name -replace '[^a-zA-Z0-9]', '_')"
                if (-not $resourceName -or $resourceName -eq "rt_") { $resourceName = "rt_$($rt.RouteTableId -replace '-', '_')" }
                
                $terraformConfig += @"
resource "aws_route_table" "$resourceName" {
  provider = aws.$regionAlias
  
  vpc_id = "$($rt.VpcId)"  # Update with vpc reference
  
  # Routes will be imported
  
  tags = {
    Name = "$($rt.Name)"
  }
}

"@
                $importCommands += "terraform import 'aws_route_table.$resourceName' $($rt.RouteTableId)`n"
            }
        }
    }
    
    # NAT Gateways
    if ($regionResources.NATGateways.Count -gt 0) {
        $terraformConfig += "`n# NAT Gateways`n"
        $importCommands += "`n# NAT Gateways in $region`n"
        
        foreach ($nat in $regionResources.NATGateways) {
            $resourceName = "nat_$($nat.Name -replace '[^a-zA-Z0-9]', '_')"
            if (-not $resourceName -or $resourceName -eq "nat_") { $resourceName = "nat_$($nat.NatGatewayId -replace '-', '_')" }
            
            $terraformConfig += @"
resource "aws_nat_gateway" "$resourceName" {
  provider = aws.$regionAlias
  
  subnet_id = "$($nat.SubnetId)"  # Update with subnet reference
  
  # Allocation ID will be imported
  
  tags = {
    Name = "$($nat.Name)"
  }
}

"@
            $importCommands += "terraform import 'aws_nat_gateway.$resourceName' $($nat.NatGatewayId)`n"
        }
    }
    
    # Network ACLs (non-default)
    if ($regionResources.NetworkACLs.Count -gt 0) {
        $terraformConfig += "`n# Network ACLs`n"
        $importCommands += "`n# Network ACLs in $region`n"
        
        foreach ($nacl in $regionResources.NetworkACLs) {
            $resourceName = "nacl_$($nacl.Name -replace '[^a-zA-Z0-9]', '_')"
            if (-not $resourceName -or $resourceName -eq "nacl_") { $resourceName = "nacl_$($nacl.NetworkAclId -replace '-', '_')" }
            
            $terraformConfig += @"
resource "aws_network_acl" "$resourceName" {
  provider = aws.$regionAlias
  
  vpc_id = "$($nacl.VpcId)"  # Update with vpc reference
  
  # Rules will be imported
  
  tags = {
    Name = "$($nacl.Name)"
  }
}

"@
            $importCommands += "terraform import 'aws_network_acl.$resourceName' $($nacl.NetworkAclId)`n"
        }
    }
    
    # Save region-specific terraform file
    $terraformConfig | Set-Content "$OutputDir\$region.tf"
    Write-Host "  Generated: $OutputDir\$region.tf" -ForegroundColor Green
}

# Save import commands
$importCommands | Set-Content "$OutputDir\import-commands.sh"
Write-Host "  Generated: $OutputDir\import-commands.sh" -ForegroundColor Green

# Create a README for the import process
$readme = @"
# Terraform Import Instructions

## Overview
This directory contains auto-generated Terraform configurations for importing existing AWS resources.

## Files Generated
- **providers.tf** - AWS provider configuration for all regions
- **[region].tf** - Resource configurations for each region
- **import-commands.sh** - Bash script with all import commands

## Import Process

### Step 1: Review and Edit Configuration Files
1. Review the generated .tf files
2. Update resource references (replace hardcoded IDs with references)
3. Add any missing configuration parameters

### Step 2: Initialize Terraform
```bash
terraform init
```

### Step 3: Run Import Commands
You can run all imports at once:
```bash
chmod +x import-commands.sh
./import-commands.sh
```

Or import resources individually:
```bash
terraform import 'aws_vpc.vpc_name' vpc-12345678
```

### Step 4: Verify Import
After importing, run:
```bash
terraform plan
```

This will show you what configuration needs to be updated to match the actual AWS resources.

### Step 5: Update Configuration
Based on the plan output, update your .tf files to match the actual resource configuration.

## Important Notes

1. **Resource References**: The generated files use hardcoded IDs. Update these to use proper Terraform references:
   ```hcl
   # Change from:
   vpc_id = "vpc-12345678"
   
   # To:
   vpc_id = aws_vpc.my_vpc.id
   ```

2. **Security Groups**: Import doesn't capture ingress/egress rules. Add these manually or use:
   ```bash
   terraform import 'aws_security_group_rule.my_rule' 'sg-12345678_ingress_tcp_80_80_0.0.0.0/0'
   ```

3. **ECS Services**: May need additional configuration like load balancer settings, network configuration, etc.

4. **Tags**: Review and standardize tags across all resources.

## Troubleshooting

- **Import fails**: Check resource ID is correct and you have permissions
- **Plan shows changes**: Update the .tf file to match actual configuration
- **Missing resources**: Some resources may have dependencies - import in order

## Next Steps

After successful import:
1. Organize resources into modules
2. Use variables for repeated values
3. Add outputs for important resource attributes
4. Consider using workspaces for different environments
"@

$readme | Set-Content "$OutputDir\README.md"
Write-Host "  Generated: $OutputDir\README.md" -ForegroundColor Green

# Create a summary report
$summaryReport = @"
# Resource Discovery Summary
Generated on: $(Get-Date)

## Resources by Region

"@

foreach ($region in $resources.PSObject.Properties.Name | Where-Object { $_ -ne "global" }) {
    $r = $resources.$region
    $totalResources = 0
    
    $summaryReport += "`n### $region`n`n"
    $summaryReport += "| Resource Type | Count |`n"
    $summaryReport += "|---------------|-------|`n"
    
    @(
        @{Name="VPCs"; Count=$r.VPCs.Count},
        @{Name="Subnets"; Count=$r.Subnets.Count},
        @{Name="Security Groups"; Count=$r.SecurityGroups.Count},
        @{Name="Route Tables"; Count=$r.RouteTables.Count},
        @{Name="Internet Gateways"; Count=$r.InternetGateways.Count},
        @{Name="NAT Gateways"; Count=$r.NATGateways.Count},
        @{Name="Network ACLs"; Count=$r.NetworkACLs.Count},
        @{Name="ECS Clusters"; Count=$r.ECSClusters.Count},
        @{Name="ECS Services"; Count=$r.ECSServices.Count},
        @{Name="ALBs"; Count=$r.ALBs.Count},
        @{Name="Target Groups"; Count=$r.TargetGroups.Count}
    ) | ForEach-Object {
        if ($_.Count -gt 0) {
            $summaryReport += "| $($_.Name) | $($_.Count) |`n"
            $totalResources += $_.Count
        }
    }
    
    $summaryReport += "`n**Total Resources in $region**: $totalResources`n"
}

$summaryReport | Set-Content "$OutputDir\SUMMARY.md"
Write-Host "  Generated: $OutputDir\SUMMARY.md" -ForegroundColor Green

Write-Host "`n✅ Terraform import configuration generated successfully!" -ForegroundColor Green
Write-Host "`nOutput directory: $OutputDir" -ForegroundColor Yellow
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. cd $OutputDir" -ForegroundColor White
Write-Host "2. Review and edit the .tf files" -ForegroundColor White
Write-Host "3. terraform init" -ForegroundColor White
Write-Host "4. Run import-commands.sh or import resources individually" -ForegroundColor White
Write-Host "5. terraform plan to verify imports" -ForegroundColor White