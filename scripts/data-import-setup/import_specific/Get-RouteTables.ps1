# Get-RouteTables.ps1
function Get-RouteTables {
    param (
        [string]$Region,
        [hashtable]$Resources,
        [string]$AccountId
    )
    Write-Host "Discovering Route Tables in $Region for Account $AccountId"
    $routeTables = Invoke-AWSCommand -Command "aws ec2 describe-route-tables --output json" -Description "Route Tables"
    if ($routeTables.RouteTables) {
        foreach ($rt in $routeTables.RouteTables) {
            $name = if ($rt.PSObject.Properties['Tags'] -and ($rt.Tags | Where-Object { $_.Key -eq "Name" })) {
                ($rt.Tags | Where-Object { $_.Key -eq "Name" }).Value
            } else {
                "Unnamed"
            }
            $isMain = $rt.Associations | Where-Object { $_.Main -eq $true }
            
            # Collect route details
            $routes = @()
            foreach ($route in $rt.Routes) {
                $routeInfo = @{
                    DestinationCidrBlock = $route.DestinationCidrBlock
                    GatewayId = $route.GatewayId
                    InstanceId = $route.InstanceId
                    NatGatewayId = $route.NatGatewayId
                    NetworkInterfaceId = $route.NetworkInterfaceId
                    VpcPeeringConnectionId = $route.VpcPeeringConnectionId
                    State = $route.State
                }
                # Remove null or empty properties to keep output clean
                $routeInfo = $routeInfo.GetEnumerator() | Where-Object { $_.Value } | ForEach-Object { @{ $_.Key = $_.Value } }
                $routes += $routeInfo
            }
            
            $Resources.RouteTables += @{
                RouteTableId = $rt.RouteTableId
                Name = $name
                VpcId = $rt.VpcId
                Routes = $routes
                RoutesCount = $rt.Routes.Count
                IsMain = [bool]$isMain
                Region = $Region
                AccountId = $AccountId
            }
            Write-Host "$($rt.RouteTableId) - $name (Routes: $($rt.Routes.Count))"
        }
    } else {
        Write-Host "No Route Tables found or error accessing Account $AccountId in $Region"
    }
    Write-Host "Route Tables discovered in $Region for Account $AccountId" 
}