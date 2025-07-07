# Get-RouteTables.ps1
function Get-RouteTables {
    param (
        [string]$Region,
        [hashtable]$Resources
    )
    Write-Host "Discovering Route Tables in $Region"
    $routeTables = Invoke-AWSCommand -Command "aws ec2 describe-route-tables --output json" -Description "Route Tables"
    if ($routeTables.RouteTables) {
        foreach ($rt in $routeTables.RouteTables) {
            $name = if ($rt.PSObject.Properties['Tags'] -and ($rt.Tags | Where-Object { $_.Key -eq "Name" })) {
                ($rt.Tags | Where-Object { $_.Key -eq "Name" }).Value
            } else {
                "Unnamed"
            }
            $isMain = $rt.Associations | Where-Object { $_.Main -eq $true }
            $Resources.RouteTables += @{
                RouteTableId = $rt.RouteTableId
                Name = $name
                VpcId = $rt.VpcId
                Routes = $rt.Routes.Count
                IsMain = [bool]$isMain
                Region = $Region
            }
        }
    }
    Write-Host "Route Tables discovered in $Region"
}