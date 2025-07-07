# Main.ps1
# Initialize the environment and call resource discovery functions

param(
    [Parameter(Mandatory=$false)]
    [string]$AccountId ="109038807292",
    
    [Parameter(Mandatory=$false)]
    [string[]]$Regions = @("us-east-1")
)

# Define the Invoke-AWSCommand function
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

Write-Host "AWS Resource Discovery for Account ID: $AccountId" -ForegroundColor Green
Write-Host "Regions to check: $($Regions -join ', ')" -ForegroundColor Yellow
Write-Host "=" * 60 -ForegroundColor Gray

# Initialize the resources hashtable with AccountId
$allResources = @{
    AccountId = $AccountId
    Regions = @{}
}

# Load subfile functions
# . .\Get-ECSClusters.ps1
# . .\Get-ECSServices.ps1
# . .\Get-ECSTaskDefinitions.ps1
# . .\Get-ALBs.ps1
# . .\Get-TargetGroups.ps1
#  . .\Get-VPCs.ps1
#  . .\Get-Subnets.ps1
# . .\Get-SecurityGroups.ps1
# . .\Get-RouteTables.ps1
# . .\Get-InternetGateways.ps1
# . .\Get-NATGateways.ps1
# . .\Get-DHCPOptionSets.ps1
# . .\Get-NetworkACLs.ps1
# . .\Get-EC2Instances.ps1
# . .\Get-RDSInstances.ps1

# Iterate over regions and collect resources
foreach ($region in $Regions) {
    $env:AWS_DEFAULT_REGION = $region
    Write-Host "Processing region: $region" -ForegroundColor Cyan

    # Initialize region-specific resources
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
        RDSInstances = @()
    }

    # Call each resource discovery function, passing AccountId

    # Get-ECSClusters -Region $region -Resources $regionResources -AccountId $AccountId
    # Get-ECSServices -Region $region -Resources $regionResources -AccountId $AccountId
    # Get-ECSTaskDefinitions -Region $region -Resources $regionResources -AccountId $AccountId
    # Get-ALBs -Region $region -Resources $regionResources -AccountId $AccountId
    # Get-TargetGroups -Region $region -Resources $regionResources -AccountId $AccountId
    Write-Host "Discovering VPCs in $Region for Account $AccountId"
    $vpcs = Invoke-AWSCommand -Command "aws ec2 describe-vpcs --output json" -Description "VPCs"
    if ($vpcs.Vpcs) {
        foreach ($vpc in $vpcs.Vpcs) {
            $name = if ($vpc.PSObject.Properties['Tags'] -and ($vpc.Tags | Where-Object { $_.Key -eq "Name" })) {
                ($vpc.Tags | Where-Object { $_.Key -eq "Name" }).Value
            } else {
                "Unnamed"
            }
            $regionResources.VPCs += @{
                VpcId = $vpc.VpcId
                Name = $name
                CidrBlock = $vpc.CidrBlock
                State = $vpc.State
                Region = $Region
                AccountId = $AccountId
            }
        }
    }
    Write-Host "VPCs discovered in $Region for Account $AccountId"
     
    Write-Host "Discovering Subnets in $Region for Account $AccountId"
    $subnets = Invoke-AWSCommand -Command "aws ec2 describe-subnets --output json" -Description "Subnets"
    if ($subnets.Subnets) {
        foreach ($subnet in $subnets.Subnets) {
            $name = if ($subnet.PSObject.Properties['Tags'] -and ($subnet.Tags | Where-Object { $_.Key -eq "Name" })) {
                ($subnet.Tags | Where-Object { $_.Key -eq "Name" }).Value
            } else {
                "Unnamed"
            }
            $regionResources.Subnets += @{
                SubnetId = $subnet.SubnetId
                Name = $name
                VpcId = $subnet.VpcId
                CidrBlock = $subnet.CidrBlock
                AvailabilityZone = $subnet.AvailabilityZone
                Type = if ($subnet.MapPublicIpOnLaunch) { "Public" } else { "Private" }
                Region = $Region
            }
        }
    }
    Write-Host "Subnets discovered in $Region for Account $AccountId"
     
    # Get-SecurityGroups -Region $region -Resources $regionResources -AccountId $AccountId
    Write-Host "Discovering Security Groups in $Region for Account $AccountId"
    $sgs = Invoke-AWSCommand -Command "aws ec2 describe-security-groups --output json" -Description "Security Groups"
    if ($sgs.SecurityGroups) {
        foreach ($sg in $sgs.SecurityGroups ) {
            $regionResources.SecurityGroups += @{
                GroupId = $sg.GroupId
                GroupName = $sg.GroupName
                Description = $sg.Description
                VpcId = $sg.VpcId
                IngressRules = $sg.IpPermissions.Count
                EgressRules = $sg.IpPermissionsEgress.Count
                Region = $Region
            }
        }
    }
    Write-Host "Security Groups discovered in $Region for Account $AccountId"    
    # Get-RouteTables -Region $region -Resources $regionResources -AccountId $AccountId
    Write-Host "Discovering Route Tables in $Region for Account $AccountId"
    $routeTables = Invoke-AWSCommand -Command "aws ec2 describe-route-tables --output json" -Description "Route Tables"
    if ($routeTables.RouteTables) {
        foreach ($rt in $routeTables.RouteTables) {
            $name = if ($rt.PSObject.Properties['Tags'] -and ($rt.Tags | Where-Object { $_.Key -eq "Name" })) {
                ($rt.Tags | Where-Object { $_.Key -eq "Name" }).Value
            } else {
                "Unnamed"
            }
            $isMain = $rt.Associations | Where-Object { $_.Main -eq $true }
            
            # Collect route details
            $routes = @()
            foreach ($route in $rt.Routes) {
                $routeInfo = @{
                    DestinationCidrBlock = $route.DestinationCidrBlock
                    GatewayId = $route.GatewayId
                    InstanceId = $route.InstanceId
                    NatGatewayId = $route.NatGatewayId
                    NetworkInterfaceId = $route.NetworkInterfaceId
                    VpcPeeringConnectionId = $route.VpcPeeringConnectionId
                    State = $route.State
                }
                # Remove null or empty properties to keep output clean
                $routeInfo = $routeInfo.GetEnumerator() | Where-Object { $_.Value } | ForEach-Object { @{ $_.Key = $_.Value } }
                $routes += $routeInfo
            }
            
            $regionResources.RouteTables += @{
                RouteTableId = $rt.RouteTableId
                Name = $name
                VpcId = $rt.VpcId
                Routes = $routes
                RoutesCount = $rt.Routes.Count
                IsMain = [bool]$isMain
                Region = $Region
                AccountId = $AccountId
            }
            Write-Host "$($rt.RouteTableId) - $name (Routes: $($rt.Routes.Count))"
        }
    } else {
        Write-Host "No Route Tables found or error accessing Account $AccountId in $Region"
    }
    Write-Host "Route Tables discovered in $Region for Account $AccountId" 
    # Write-Host "Discovering Route Tables in $Region  for Account $AccountId"
    # $routeTables = Invoke-AWSCommand -Command "aws ec2 describe-route-tables --output json" -Description "Route Tables"
    # if ($routeTables.RouteTables) {
    #     foreach ($rt in $routeTables.RouteTables) {
    #         $name = if ($rt.PSObject.Properties['Tags'] -and ($rt.Tags | Where-Object { $_.Key -eq "Name" })) {
    #             ($rt.Tags | Where-Object { $_.Key -eq "Name" }).Value
    #         } else {
    #             "Unnamed"
    #         }
    #         $isMain = $rt.Associations | Where-Object { $_.Main -eq $true }
    #         $regionResources.RouteTables += @{
    #             RouteTableId = $rt.RouteTableId
    #             Name = $name
    #             VpcId = $rt.VpcId
    #             Routes = $rt.Routes.Count
    #             IsMain = [bool]$isMain
    #             Region = $Region
    #         }
    #     }
    # }
    # Write-Host "Route Tables discovered in $Region for Account $AccountId"    
    # Get-InternetGateways -Region $region -Resources $regionResources -AccountId $AccountId
    Write-Host "Discovering Internet Gateways in $Region for Account $AccountId" 
    $igws = Invoke-AWSCommand -Command "aws ec2 describe-internet-gateways --output json" -Description "Internet Gateways"
    if ($igws.InternetGateways) {
        foreach ($igw in $igws.InternetGateways) {
            $name = if ($igw.PSObject.Properties['Tags'] -and ($igw.Tags | Where-Object { $_.Key -eq "Name" })) {
                ($igw.Tags | Where-Object { $_.Key -eq "Name" }).Value
            } else {
                "Unnamed"
            }
            $attachedVpc = $igw.Attachments[0].VpcId
            $regionResources.InternetGateways += @{
                InternetGatewayId = $igw.InternetGatewayId
                Name = $name
                AttachedVpcId = $attachedVpc
                Region = $Region
            }
        }
    }
    Write-Host "Internet Gateways discovered in $Region for Account $AccountId"     
    # Get-NATGateways -Region $region -Resources $regionResources -AccountId $AccountId
    # Get-DHCPOptionSets -Region $region -Resources $regionResources -AccountId $AccountId
    Write-Host "Discovering DHCP Option Sets in $Region for Account $AccountId"
    $dhcp = Invoke-AWSCommand -Command "aws ec2 describe-dhcp-options --output json" -Description "DHCP Option Sets"
    if ($dhcp.DhcpOptions) {
        foreach ($dhcp in $dhcp.DhcpOptions) {
            $name = if ($dhcp.PSObject.Properties['Tags'] -and ($dhcp.Tags | Where-Object { $_.Key -eq "Name" })) {
                ($dhcp.Tags | Where-Object { $_.Key -eq "Name" }).Value
            } else {
                "Unnamed"
            }
            $regionResources.DHCPOptionSets += @{
                DhcpOptionsId = $dhcp.DhcpOptionsId
                Name = $name
                Region = $Region
            }
        }
    }
    Write-Host "DHCP Option Sets discovered in $Region for Account $AccountId"    
    # Get-NetworkACLs -Region $region -Resources $regionResources -AccountId $AccountId
    Write-Host "Discovering Network ACLs in $Region for Account $AccountId"
    $nacls = Invoke-AWSCommand -Command "aws ec2 describe-network-acls --output json" -Description "Network ACLs"
    if ($nacls.NetworkAcls) {
        foreach ($nacl in $nacls.NetworkAcls ) {
            $name = if ($nacl.PSObject.Properties['Tags'] -and ($nacl.Tags | Where-Object { $_.Key -eq "Name" })) {
                ($nacl.Tags | Where-Object { $_.Key -eq "Name" }).Value
            } else {
                "Unnamed"
            }
            $regionResources.NetworkACLs += @{
                NetworkAclId = $nacl.NetworkAclId
                Name = $name
                VpcId = $nacl.VpcId
                IsDefault = $nacl.IsDefault
                Region = $Region
            }
        }
    }
    Write-Host "Network ACLs discovered in $Region for Account $AccountId"    
    # Get-EC2Instances -Region $region -Resources $regionResources -AccountId $AccountId
    # Get-RDSInstances -Region $region -Resources $regionResources -AccountId $AccountId

    # Store region resources in allResources
    $allResources.Regions[$region] = $regionResources
}

# Save results to JSON
$allResources | ConvertTo-Json -Depth 10 | Out-File "aws_resources.json"
Write-Host "Resource discovery complete. Results saved to aws_resources.json" -ForegroundColor Green