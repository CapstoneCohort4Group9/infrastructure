# Get-RDSInstances.ps1
function Get-RDSInstances {
    param (
        [string]$Region,
        [hashtable]$Resources
    )
    Write-Host "Discovering RDS Instances in $Region"
    $dbInstances = Invoke-AWSCommand -Command "aws rds describe-db-instances --output json" -Description "RDS Instances"
    if ($dbInstances.DBInstances) {
        foreach ($db in $dbInstances.DBInstances) {
            $name = if ($db.PSObject.Properties['TagList'] -and ($db.TagList | Where-Object { $_.Key -eq "Name" })) {
                ($db.TagList | Where-Object { $_.Key -eq "Name" }).Value
            } else {
                "Unnamed"
            }
            $Resources.RDSInstances += @{
                DBInstanceIdentifier = $db.DBInstanceIdentifier
                Name = $name
                Engine = $db.Engine
                EngineVersion = $db.EngineVersion
                DBInstanceStatus = $db.DBInstanceStatus
                Endpoint = $db.Endpoint.Address
                Port = $db.Endpoint.Port
                VpcId = $db.DBSubnetGroup.VpcId
                Region = $Region
            }
        }
    }
    Write-Host "RDS Instances discovered in $Region"
}