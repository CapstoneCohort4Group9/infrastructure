# Get-NATGateways.ps1
function Get-NATGateways {
    param (
        [string]$Region,
        [hashtable]$Resources
    )
    Write-Host "Discovering NAT Gateways in $Region"
    $natGateways = Invoke-AWSCommand -Command "aws ec2 describe-nat-gateways --output json" -Description "NAT Gateways"
    if ($natGateways.NatGateways) {
        foreach ($nat in $natGateways.NatGateways) {
            if ($nat.State -ne "deleted") {
                $name = if ($nat.PSObject.Properties['Tags'] -and ($nat.Tags | Where-Object { $_.Key -eq "Name" })) {
                    ($nat.Tags | Where-Object { $_.Key -eq "Name" }).Value
                } else {
                    "Unnamed"
                }
                $Resources.NATGateways += @{
                    NatGatewayId = $nat.NatGatewayId  # Corrected from NatGatewayId =ntGatewayId
                    Name = $name
                    SubnetId = $nat.SubnetId
                    State = $nat.State
                    Region = $Region
                }
            }
        }
    }
    Write-Host "NAT Gateways discovered in $Region"
}