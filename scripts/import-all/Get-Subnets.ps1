# Get-Subnets.ps1
function Get-Subnets {
    param (
        [string]$Region,
        [hashtable]$Resources
    )
    Write-Host "Discovering Subnets in $Region"
    $subnets = Invoke-AWSCommand -Command "aws ec2 describe-subnets --output json" -Description "Subnets"
    if ($subnets.Subnets) {
        foreach ($subnet in $subnets.Subnets) {
            $name = if ($subnet.PSObject.Properties['Tags'] -and ($subnet.Tags | Where-Object { $_.Key -eq "Name" })) {
                ($subnet.Tags | Where-Object { $_.Key -eq "Name" }).Value
            } else {
                "Unnamed"
            }
            $Resources.Subnets += @{
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
    Write-Host "Subnets discovered in $Region"
}