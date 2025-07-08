# Main.ps1
# Initialize the environment and call resource discovery functions

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

# List of regions to scan (example)
$regions = @("ap-southeast-2")

# Initialize the resources hashtable
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
    RDSInstances = @()  # Added RDSInstances
}

# Load subfile functions
. .\Get-ECSClusters.ps1
. .\Get-ECSServices.ps1
. .\Get-ECSTaskDefinitions.ps1
. .\Get-ALBs.ps1
. .\Get-TargetGroups.ps1
. .\Get-VPCs.ps1
. .\Get-Subnets.ps1
. .\Get-SecurityGroups.ps1
. .\Get-RouteTables.ps1
. .\Get-InternetGateways.ps1
. .\Get-NATGateways.ps1
. .\Get-DHCPOptionSets.ps1
. .\Get-NetworkACLs.ps1
. .\Get-EC2Instances.ps1
. .\Get-RDSInstances.ps1  # Added RDS subfile

# Iterate over regions and collect resources
foreach ($region in $regions) {
    $env:AWS_DEFAULT_REGION = $region
    Write-Host "Processing region: $region"

    # Call each resource discovery function
    # Comment/uncomment to test specific resources
    Get-ECSClusters -Region $region -Resources $regionResources
    Get-ECSServices -Region $region -Resources $regionResources
    Get-ECSTaskDefinitions -Region $region -Resources $regionResources
    Get-ALBs -Region $region -Resources $regionResources
    Get-TargetGroups -Region $region -Resources $regionResources
    Get-VPCs -Region $region -Resources $regionResources
    Get-Subnets -Region $region -Resources $regionResources
    Get-SecurityGroups -Region $region -Resources $regionResources
    Get-RouteTables -Region $region -Resources $regionResources
    Get-InternetGateways -Region $region -Resources $regionResources
    Get-NATGateways -Region $region -Resources $regionResources
    Get-DHCPOptionSets -Region $region -Resources $regionResources
    Get-NetworkACLs -Region $region -Resources $regionResources
    Get-EC2Instances -Region $region -Resources $regionResources
    Get-RDSInstances -Region $region -Resources $regionResources  # Added RDS function call
}

# Save results to JSON
$regionResources | ConvertTo-Json -Depth 10 | Out-File "aws_resources.json"
Write-Host "Resource discovery complete. Results saved to aws_resources.json"