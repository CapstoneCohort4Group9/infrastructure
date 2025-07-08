# Get-VPCs.ps1
function Get-VPCs {
    param (
        [string]$Region,
        [hashtable]$Resources
    )
    Write-Host "Discovering VPCs in $Region"
    $vpcs = Invoke-AWSCommand -Command "aws ec2 describe-vpcs --output json" -Description "VPCs"
    if ($vpcs.Vpcs) {
        foreach ($vpc in $vpcs.Vpcs) {
            $name = if ($vpc.PSObject.Properties['Tags'] -and ($vpc.Tags | Where-Object { $_.Key -eq "Name" })) {
                ($vpc.Tags | Where-Object { $_.Key -eq "Name" }).Value
            } else {
                "Unnamed"
            }
            $Resources.VPCs += @{
                VpcId = $vpc.VpcId
                Name = $name
                CidrBlock = $vpc.CidrBlock
                State = $vpc.State
                Region = $Region
            }
        }
    }
    Write-Host "VPCs discovered in $Region"
}