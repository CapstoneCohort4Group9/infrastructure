# Get-TargetGroups.ps1
function Get-TargetGroups {
    param (
        [string]$Region,
        [hashtable]$Resources
    )
    Write-Host "Discovering Target Groups in $Region"
    $targetGroups = Invoke-AWSCommand -Command "aws elbv2 describe-target-groups --output json" -Description "Target Groups"
    if ($targetGroups.TargetGroups) {
        foreach ($tg in $targetGroups.TargetGroups) {
            $Resources.TargetGroups += @{
                TargetGroupArn = $tg.TargetGroupArn
                TargetGroupName = $tg.TargetGroupName
                Protocol = $tg.Protocol
                Port = $tg.Port
                VpcId = $tg.VpcId
                TargetType = $tg.TargetType
                HealthCheckPath = $tg.HealthCheckPath
                Region = $Region
            }
        }
    }
    Write-Host "Target Groups discovered in $Region"
}