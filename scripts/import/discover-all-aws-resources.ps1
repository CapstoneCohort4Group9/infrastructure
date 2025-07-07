# Comprehensive AWS Resource Discovery Script

param(
    [Parameter(Mandatory=$false)]
    [string[]]$Regions = @("ap-southeast-2"),
    
    [Parameter(Mandatory=$false)]
    [switch]$ExportTerraform = $false
)

Write-Host "AWS Comprehensive Resource Discovery Tool" -ForegroundColor Green
Write-Host "Regions to check: $($Regions -join ', ')" -ForegroundColor Yellow
Write-Host "=" * 60 -ForegroundColor Gray

# Initialize results
$allResources = @{}

# Function to safely execute AWS commands
function Invoke-AWSCommand {
    param(
        [string]$Command,
        [string]$Description
    )
    
    try {
        $result = Invoke-Expression $Command 2>$null
        if ($LASTEXITCODE -eq 0 -and $result) {
            return $result | ConvertFrom-Json
        }
    } catch {
        Write-Host "    Error getting $Description" -ForegroundColor DarkGray
    }
    return $null
}

# Discover Regional Resources
foreach ($region in $Regions) {
    Write-Host "`nDiscovering Resources in $region" -ForegroundColor Cyan
    Write-Host "-" * 40 -ForegroundColor Gray
    $env:AWS_DEFAULT_REGION = $region
    
    $regionResources = @{
        ECSClusters = @()
        ECSServices = @()
        ECSTaskDefinitions = @()
        ALBs = @()
        TargetGroups = @()
        VPCs = @()
        Subnets = @()
        SecurityGroups = @()
        RouteTables = @()
        InternetGateways = @()
        NATGateways = @()
        DHCPOptionSets = @()
        NetworkACLs = @()
        EC2Instances = @()
    }
    
    # VPCs (get these first as other resources depend on them)
    Write-Host "`n  [VPCs]" -ForegroundColor Yellow
    $vpcs = Invoke-AWSCommand -Command "aws ec2 describe-vpcs --output json" -Description "VPCs"
    if ($vpcs.Vpcs) {
        foreach ($vpc in $vpcs.Vpcs) {
            $name = ($vpc.Tags | Where-Object { $_.Key -eq "Name" }).Value
            if (-not $name) { $name = "Unnamed" }
            $vpcInfo = @{
                VpcId = $vpc.VpcId
                Name = $name
                CidrBlock = $vpc.CidrBlock
                IsDefault = $vpc.IsDefault
            }
            $regionResources.VPCs += $vpcInfo
            Write-Host "    ✓ $($vpc.VpcId) - $name $(if($vpc.IsDefault){'(default)'})" -ForegroundColor Gray
        }
    }
    
    # Subnets
    Write-Host "`n  [Subnets]" -ForegroundColor Yellow
    $subnets = Invoke-AWSCommand -Command "aws ec2 describe-subnets --output json" -Description "Subnets"
    if ($subnets.Subnets) {
        foreach ($subnet in $subnets.Subnets) {
            $name = ($subnet.Tags | Where-Object { $_.Key -eq "Name" }).Value
            if (-not $name) { $name = "Unnamed" }
            $regionResources.Subnets += @{
                SubnetId = $subnet.SubnetId
                Name = $name
                VpcId = $subnet.VpcId
                CidrBlock = $subnet.CidrBlock
                AvailabilityZone = $subnet.AvailabilityZone
                Type = if ($subnet.MapPublicIpOnLaunch) { "Public" } else { "Private" }
            }
            Write-Host "    ✓ $($subnet.SubnetId) - $name ($($subnet.CidrBlock))" -ForegroundColor Gray
        }
    }
    
    # Security Groups
    Write-Host "`n  [Security Groups]" -ForegroundColor Yellow
    $sgs = Invoke-AWSCommand -Command "aws ec2 describe-security-groups --output json" -Description "Security Groups"
    if ($sgs.SecurityGroups) {
        foreach ($sg in $sgs.SecurityGroups) {
            if ($sg.GroupName -ne "default") {  # Skip default SGs
                $regionResources.SecurityGroups += @{
                    GroupId = $sg.GroupId
                    GroupName = $sg.GroupName
                    Description = $sg.Description
                    VpcId = $sg.VpcId
                    IngressRules = $sg.IpPermissions.Count
                    EgressRules = $sg.IpPermissionsEgress.Count
                }
                Write-Host "    ✓ $($sg.GroupId) - $($sg.GroupName)" -ForegroundColor Gray
            }
        }
    }
    
    # Route Tables
    Write-Host "`n  [Route Tables]" -ForegroundColor Yellow
    $routeTables = Invoke-AWSCommand -Command "aws ec2 describe-route-tables --output json" -Description "Route Tables"
    if ($routeTables.RouteTables) {
        foreach ($rt in $routeTables.RouteTables) {
            $name = ($rt.Tags | Where-Object { $_.Key -eq "Name" }).Value
            if (-not $name) { $name = "Unnamed" }
            $isMain = $rt.Associations | Where-Object { $_.Main -eq $true }
            $regionResources.RouteTables += @{
                RouteTableId = $rt.RouteTableId
                Name = $name
                VpcId = $rt.VpcId
                Routes = $rt.Routes.Count
                IsMain = [bool]$isMain
            }
            Write-Host "    ✓ $($rt.RouteTableId) - $name $(if($isMain){'(main)'})" -ForegroundColor Gray
        }
    }
    
    # Internet Gateways
    Write-Host "`n  [Internet Gateways]" -ForegroundColor Yellow
    $igws = Invoke-AWSCommand -Command "aws ec2 describe-internet-gateways --output json" -Description "Internet Gateways"
    if ($igws.InternetGateways) {
        foreach ($igw in $igws.InternetGateways) {
            $name = ($igw.Tags | Where-Object { $_.Key -eq "Name" }).Value
            if (-not $name) { $name = "Unnamed" }
            $attachedVpc = $igw.Attachments[0].VpcId
            $regionResources.InternetGateways += @{
                InternetGatewayId = $igw.InternetGatewayId
                Name = $name
                AttachedVpcId = $attachedVpc
            }
            Write-Host "    ✓ $($igw.InternetGatewayId) - $name (VPC: $attachedVpc)" -ForegroundColor Gray
        }
    }
    
    # NAT Gateways
    Write-Host "`n  [NAT Gateways]" -ForegroundColor Yellow
    $natGateways = Invoke-AWSCommand -Command "aws ec2 describe-nat-gateways --output json" -Description "NAT Gateways"
    if ($natGateways.NatGateways) {
        foreach ($nat in $natGateways.NatGateways | Where-Object { $_.State -ne "deleted" }) {
            $name = ($nat.Tags | Where-Object { $_.Key -eq "Name" }).Value
            if (-not $name) { $name = "Unnamed" }
            $regionResources.NATGateways += @{
                NatGatewayId = $nat.NatGatewayId
                Name = $name
                SubnetId = $nat.SubnetId
                State = $nat.State
            }
            Write-Host "    ✓ $($nat.NatGatewayId) - $name ($($nat.State))" -ForegroundColor Gray
        }
    }
    
    # DHCP Option Sets
    Write-Host "`n  [DHCP Option Sets]" -ForegroundColor Yellow
    $dhcpSets = Invoke-AWSCommand -Command "aws ec2 describe-dhcp-options --output json" -Description "DHCP Option Sets"
    if ($dhcpSets.DhcpOptions) {
        foreach ($dhcp in $dhcpSets.DhcpOptions) {
            $name = ($dhcp.Tags | Where-Object { $_.Key -eq "Name" }).Value
            if (-not $name) { $name = "Unnamed" }
            $regionResources.DHCPOptionSets += @{
                DhcpOptionsId = $dhcp.DhcpOptionsId
                Name = $name
            }
            Write-Host "    ✓ $($dhcp.DhcpOptionsId) - $name" -ForegroundColor Gray
        }
    }
    
    # Network ACLs
    Write-Host "`n  [Network ACLs]" -ForegroundColor Yellow
    $nacls = Invoke-AWSCommand -Command "aws ec2 describe-network-acls --output json" -Description "Network ACLs"
    if ($nacls.NetworkAcls) {
        foreach ($nacl in $nacls.NetworkAcls | Where-Object { -not $_.IsDefault }) {
            $name = ($nacl.Tags | Where-Object { $_.Key -eq "Name" }).Value
            if (-not $name) { $name = "Unnamed" }
            $regionResources.NetworkACLs += @{
                NetworkAclId = $nacl.NetworkAclId
                Name = $name
                VpcId = $nacl.VpcId
                IsDefault = $nacl.IsDefault
            }
            Write-Host "    ✓ $($nacl.NetworkAclId) - $name" -ForegroundColor Gray
        }
    }
    
    # ECS Clusters
    Write-Host "`n  [ECS Clusters]" -ForegroundColor Yellow
    $clusterArns = Invoke-AWSCommand -Command "aws ecs list-clusters --output json" -Description "ECS Clusters"
    if ($clusterArns.clusterArns) {
        foreach ($clusterArn in $clusterArns.clusterArns) {
            $clusterDetail = Invoke-AWSCommand -Command "aws ecs describe-clusters --clusters `"$clusterArn`" --output json" -Description "Cluster Details"
            if ($clusterDetail.clusters) {
                $cluster = $clusterDetail.clusters[0]
                $regionResources.ECSClusters += @{
                    ClusterArn = $cluster.clusterArn
                    ClusterName = $cluster.clusterName
                    Status = $cluster.status
                    RegisteredContainerInstances = $cluster.registeredContainerInstancesCount
                    RunningTasks = $cluster.runningTasksCount
                    ActiveServices = $cluster.activeServicesCount
                }
                Write-Host "    ✓ $($cluster.clusterName) (Services: $($cluster.activeServicesCount), Tasks: $($cluster.runningTasksCount))" -ForegroundColor Gray
                
                # Get services in this cluster
                $serviceArns = Invoke-AWSCommand -Command "aws ecs list-services --cluster `"$clusterArn`" --output json" -Description "ECS Services"
                if ($serviceArns.serviceArns) {
                    foreach ($serviceArn in $serviceArns.serviceArns) {
                        $serviceDetail = Invoke-AWSCommand -Command "aws ecs describe-services --cluster `"$clusterArn`" --services `"$serviceArn`" --output json" -Description "Service Details"
                        if ($serviceDetail.services) {
                            $service = $serviceDetail.services[0]
                            $regionResources.ECSServices += @{
                                ServiceArn = $service.serviceArn
                                ServiceName = $service.serviceName
                                ClusterArn = $clusterArn
                                LaunchType = $service.launchType
                                DesiredCount = $service.desiredCount
                                RunningCount = $service.runningCount
                                TaskDefinition = $service.taskDefinition
                            }
                            Write-Host "      → Service: $($service.serviceName) ($($service.launchType), Running: $($service.runningCount)/$($service.desiredCount))" -ForegroundColor DarkGray
                        }
                    }
                }
            }
        }
    }
    
    # Task Definitions (Fargate)
    Write-Host "`n  [ECS Task Definitions]" -ForegroundColor Yellow
    $taskDefArns = Invoke-AWSCommand -Command "aws ecs list-task-definitions --output json" -Description "Task Definitions"
    if ($taskDefArns.taskDefinitionArns) {
        # Get unique task definition families
        $families = @{}
        foreach ($taskDefArn in $taskDefArns.taskDefinitionArns) {
            $family = ($taskDefArn -split '/')[-1] -split ':' | Select-Object -First 1
            if (-not $families.ContainsKey($family)) {
                $families[$family] = $taskDefArn
            }
        }
        
        foreach ($family in $families.Keys) {
            $taskDef = Invoke-AWSCommand -Command "aws ecs describe-task-definition --task-definition `"$family`" --output json" -Description "Task Definition"
            if ($taskDef.taskDefinition) {
                $td = $taskDef.taskDefinition
                $regionResources.ECSTaskDefinitions += @{
                    TaskDefinitionArn = $td.taskDefinitionArn
                    Family = $td.family
                    Revision = $td.revision
                    RequiresCompatibilities = $td.requiresCompatibilities -join ", "
                    Cpu = $td.cpu
                    Memory = $td.memory
                }
                Write-Host "    ✓ $($td.family):$($td.revision) (CPU: $($td.cpu), Memory: $($td.memory))" -ForegroundColor Gray
            }
        }
    }
    
    # Application Load Balancers
    Write-Host "`n  [Application Load Balancers]" -ForegroundColor Yellow
    $albs = Invoke-AWSCommand -Command "aws elbv2 describe-load-balancers --output json" -Description "Load Balancers"
    if ($albs.LoadBalancers) {
        foreach ($alb in $albs.LoadBalancers | Where-Object { $_.Type -eq "application" }) {
            $regionResources.ALBs += @{
                LoadBalancerArn = $alb.LoadBalancerArn
                LoadBalancerName = $alb.LoadBalancerName
                DNSName = $alb.DNSName
                Scheme = $alb.Scheme
                VpcId = $alb.VpcId
                State = $alb.State.Code
                Type = $alb.Type
            }
            Write-Host "    ✓ $($alb.LoadBalancerName) ($($alb.Scheme), $($alb.State.Code))" -ForegroundColor Gray
        }
    }
    
    # Target Groups
    Write-Host "`n  [Target Groups]" -ForegroundColor Yellow
    $targetGroups = Invoke-AWSCommand -Command "aws elbv2 describe-target-groups --output json" -Description "Target Groups"
    if ($targetGroups.TargetGroups) {
        foreach ($tg in $targetGroups.TargetGroups) {
            $regionResources.TargetGroups += @{
                TargetGroupArn = $tg.TargetGroupArn
                TargetGroupName = $tg.TargetGroupName
                Protocol = $tg.Protocol
                Port = $tg.Port
                VpcId = $tg.VpcId
                TargetType = $tg.TargetType
                HealthCheckPath = $tg.HealthCheckPath
            }
            Write-Host "    ✓ $($tg.TargetGroupName) ($($tg.Protocol):$($tg.Port), Type: $($tg.TargetType))" -ForegroundColor Gray
        }
    }
    
    # EC2 Instances (for reference)
    Write-Host "`n  [EC2 Instances]" -ForegroundColor Yellow
    $instances = Invoke-AWSCommand -Command "aws ec2 describe-instances --query 'Reservations[].Instances[?State.Name!=`terminated`]' --output json" -Description "EC2 Instances"
    if ($instances) {
        foreach ($instance in $instances) {
            $name = ($instance.Tags | Where-Object { $_.Key -eq "Name" }).Value
            if (-not $name) { $name = "Unnamed" }
            $regionResources.EC2Instances += @{
                InstanceId = $instance.InstanceId
                Name = $name
                Type = $instance.InstanceType
                State = $instance.State.Name
                VpcId = $instance.VpcId
                SubnetId = $instance.SubnetId
            }
            Write-Host "    ✓ $($instance.InstanceId) - $name ($($instance.InstanceType))" -ForegroundColor Gray
        }
    }
    
    $allResources[$region] = $regionResources
}

# Save results
Write-Host "`nSaving results..." -ForegroundColor Yellow
$allResources | ConvertTo-Json -Depth 10 | Set-Content "discovered-resources.json"

# Display summary
Write-Host "`n" -NoNewline
Write-Host "=".PadRight(60, "=") -ForegroundColor Green
Write-Host "DISCOVERY SUMMARY" -ForegroundColor Green
Write-Host "=".PadRight(60, "=") -ForegroundColor Green

foreach ($region in $Regions) {
    Write-Host "`n$region" -ForegroundColor Cyan
    Write-Host "-".PadRight(40, "-") -ForegroundColor Gray
    
    $r = $allResources[$region]
    
    Write-Host "Networking:" -ForegroundColor Yellow
    Write-Host "  VPCs:                $($r.VPCs.Count)" -ForegroundColor White
    Write-Host "  Subnets:             $($r.Subnets.Count)" -ForegroundColor White
    Write-Host "  Security Groups:     $($r.SecurityGroups.Count)" -ForegroundColor White
    Write-Host "  Route Tables:        $($r.RouteTables.Count)" -ForegroundColor White
    Write-Host "  Internet Gateways:   $($r.InternetGateways.Count)" -ForegroundColor White
    Write-Host "  NAT Gateways:        $($r.NATGateways.Count)" -ForegroundColor White
    Write-Host "  DHCP Option Sets:    $($r.DHCPOptionSets.Count)" -ForegroundColor White
    Write-Host "  Network ACLs:        $($r.NetworkACLs.Count)" -ForegroundColor White
    
    Write-Host "`nCompute:" -ForegroundColor Yellow
    Write-Host "  ECS Clusters:        $($r.ECSClusters.Count)" -ForegroundColor White
    Write-Host "  ECS Services:        $($r.ECSServices.Count)" -ForegroundColor White
    Write-Host "  Task Definitions:    $($r.ECSTaskDefinitions.Count)" -ForegroundColor White
    Write-Host "  EC2 Instances:       $($r.EC2Instances.Count)" -ForegroundColor White
    
    Write-Host "`nLoad Balancing:" -ForegroundColor Yellow
    Write-Host "  ALBs:                $($r.ALBs.Count)" -ForegroundColor White
    Write-Host "  Target Groups:       $($r.TargetGroups.Count)" -ForegroundColor White
}

Write-Host "`n✅ Results saved to: discovered-resources.json" -ForegroundColor Green

if ($ExportTerraform) {
    Write-Host "`nGenerating Terraform import commands..." -ForegroundColor Yellow
    & ".\generate-terraform-imports.ps1" -ResourceFile "discovered-resources.json"
}

Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Review discovered-resources.json for detailed information" -ForegroundColor White
Write-Host "2. Run with -ExportTerraform flag to generate import commands" -ForegroundColor White
Write-Host "3. Create Terraform configurations for resources you want to import" -ForegroundColor White