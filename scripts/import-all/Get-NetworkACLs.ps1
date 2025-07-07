# Get-NetworkACLs.ps1
function Get-NetworkACLs {
    param (
        [string]$Region,
        [hashtable]$Resources
    )
    Write-Host "Discovering Network ACLs in $Region"
    $nacls = Invoke-AWSCommand -Command "aws ec2 describe-network-acls --output json" -Description "Network ACLs"
    if ($nacls.NetworkAcls) {
        foreach ($nacl in $nacls.NetworkAcls | Where-Object { -not $_.IsDefault }) {
            $name = if ($nacl.PSObject.Properties['Tags'] -and ($nacl.Tags | Where-Object { $_.Key -eq "Name" })) {
                ($nacl.Tags | Where-Object { $_.Key -eq "Name" }).Value
            } else {
                "Unnamed"
            }
            $Resources.NetworkACLs += @{
                NetworkAclId = $nacl.NetworkAclId
                Name = $name
                VpcId = $nacl.VpcId
                IsDefault = $nacl.IsDefault
                Region = $Region
            }
        }
    }
    Write-Host "Network ACLs discovered in $Region"
}