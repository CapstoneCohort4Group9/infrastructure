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
 #. .\Get-VPCs.ps1
 #. .\Get-Subnets.ps1
 #. .\Get-SecurityGroups.ps1
 . .\Get-RouteTables.ps1
 #. .\Get-InternetGateways.ps1
# . .\Get-NATGateways.ps1
 #. .\Get-DHCPOptionSets.ps1
 #. .\Get-NetworkACLs.ps1
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
    # Get-VPCs -Region $region -Resources $regionResources -AccountId $AccountId
    # Get-Subnets -Region $region -Resources $regionResources -AccountId $AccountId
    # Get-SecurityGroups -Region $region -Resources $regionResources -AccountId $AccountId
     Get-RouteTables -Region $region -Resources $regionResources -AccountId $AccountId
    #Get-InternetGateways -Region $region -Resources $regionResources -AccountId $AccountId
    # Get-NATGateways -Region $region -Resources $regionResources -AccountId $AccountId
    #Get-DHCPOptionSets -Region $region -Resources $regionResources -AccountId $AccountId
    # Get-NetworkACLs -Region $region -Resources $regionResources -AccountId $AccountId
    # Get-EC2Instances -Region $region -Resources $regionResources -AccountId $AccountId
    # Get-RDSInstances -Region $region -Resources $regionResources -AccountId $AccountId

    # Store region resources in allResources
    $allResources.Regions[$region] = $regionResources
}

# Save results to JSON
$allResources | ConvertTo-Json -Depth 10 | Out-File "aws_resources.json"
Write-Host "Resource discovery complete. Results saved to aws_resources.json" -ForegroundColor Green