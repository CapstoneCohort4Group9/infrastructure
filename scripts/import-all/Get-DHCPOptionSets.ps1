# Get-DHCPOptionSets.ps1
function Get-DHCPOptionSets {
    param (
        [string]$Region,
        [hashtable]$Resources
    )
    Write-Host "Discovering DHCP Option Sets in $Region"
    $dhcp = Invoke-AWSCommand -Command "aws ec2 describe-dhcp-options --output json" -Description "DHCP Option Sets"
    if ($dhcp.DhcpOptions) {
        foreach ($dhcp in $dhcp.DhcpOptions) {
            $name = if ($dhcp.PSObject.Properties['Tags'] -and ($dhcp.Tags | Where-Object { $_.Key -eq "Name" })) {
                ($dhcp.Tags | Where-Object { $_.Key -eq "Name" }).Value
            } else {
                "Unnamed"
            }
            $Resources.DHCPOptionSets += @{
                DhcpOptionsId = $dhcp.DhcpOptionsId
                Name = $name
                Region = $Region
            }
        }
    }
    Write-Host "DHCP Option Sets discovered in $Region"
}