# Get-SecurityGroups.ps1
function Get-SecurityGroups {
    param (
        [string]$Region,
        [hashtable]$Resources
    )
    Write-Host "Discovering Security Groups in $Region"
    $sgs = Invoke-AWSCommand -Command "aws ec2 describe-security-groups --output json" -Description "Security Groups"
    if ($sgs.SecurityGroups) {
        foreach ($sg in $sgs.SecurityGroups | Where-Object { $_.GroupName -ne "default" }) {
            $Resources.SecurityGroups += @{
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
    Write-Host "Security Groups discovered in $Region"
}