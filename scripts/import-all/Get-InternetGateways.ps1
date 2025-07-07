# Get-InternetGateways.ps1
function Get-InternetGateways {
    param (
        [string]$Region,
        [hashtable]$Resources
    )
    Write-Host "Discovering Internet Gateways in $Region"
    $igws = Invoke-AWSCommand -Command "aws ec2 describe-internet-gateways --output json" -Description "Internet Gateways"
    if ($igws.InternetGateways) {
        foreach ($igw in $igws.InternetGateways) {
            $name = if ($igw.PSObject.Properties['Tags'] -and ($igw.Tags | Where-Object { $_.Key -eq "Name" })) {
                ($igw.Tags | Where-Object { $_.Key -eq "Name" }).Value
            } else {
                "Unnamed"
            }
            $attachedVpc = $igw.Attachments[0].VpcId
            $Resources.InternetGateways += @{
                InternetGatewayId = $igw.InternetGatewayId
                Name = $name
                AttachedVpcId = $attachedVpc
                Region = $Region
            }
        }
    }
    Write-Host "Internet Gateways discovered in $Region"
}