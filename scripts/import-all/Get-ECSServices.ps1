# Get-ECSServices.ps1
function Get-ECSServices {
    param (
        [string]$Region,
        [hashtable]$Resources
    )
    Write-Host "Discovering ECS Services in $Region"
    $clusterArns = Invoke-AWSCommand -Command "aws ecs list-clusters --output json" -Description "ECS Clusters"
    if ($clusterArns.clusterArns) {
        foreach ($clusterArn in $clusterArns.clusterArns) {
            $serviceArns = Invoke-AWSCommand -Command "aws ecs list-services --cluster `"$clusterArn`" --output json" -Description "ECS Services"
            if ($serviceArns.serviceArns) {
                foreach ($serviceArn in $serviceArns.serviceArns) {
                    $serviceDetail = Invoke-AWSCommand -Command "aws ecs describe-services --cluster `"$clusterArn`" --services `"$serviceArn`" --output json" -Description "Service Details"
                    if ($serviceDetail.services) {
                        $service = $serviceDetail.services[0]
                        $Resources.ECSServices += @{
                            ServiceArn = $service.serviceArn
                            ServiceName = $service.serviceName
                            ClusterArn = $clusterArn
                            LaunchType = $service.launchType
                            DesiredCount = $service.desiredCount
                            RunningCount = $service.runningCount
                            TaskDefinition = $service.taskDefinition
                            Region = $Region
                        }
                    }
                }
            }
        }
    }
    Write-Host "ECS Services discovered in $Region"
}