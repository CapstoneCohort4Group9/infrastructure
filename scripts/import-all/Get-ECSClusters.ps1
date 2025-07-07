# Get-ECSClusters.ps1
function Get-ECSClusters {
    param (
        [string]$Region,
        [hashtable]$Resources
    )
    Write-Host "Discovering ECS Clusters in $Region"
    $clusterArns = Invoke-AWSCommand -Command "aws ecs list-clusters --output json" -Description "ECS Clusters"
    if ($clusterArns.clusterArns) {
        foreach ($clusterArn in $clusterArns.clusterArns) {
            $clusterDetail = Invoke-AWSCommand -Command "aws ecs describe-clusters --clusters `"$clusterArn`" --output json" -Description "Cluster Details"
            if ($clusterDetail.clusters) {
                $cluster = $clusterDetail.clusters[0]
                $Resources.ECSClusters += @{
                    ClusterArn = $cluster.clusterArn
                    ClusterName = $cluster.clusterName
                    Status = $cluster.status
                    RegisteredContainerInstances = $cluster.registeredContainerInstancesCount
                    RunningTasks = $cluster.runningTasksCount
                    ActiveServices = $cluster.activeServicesCount
                    Region = $Region
                }
            }
        }
    }
    Write-Host "ECS Clusters discovered in $Region"
}