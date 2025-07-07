# Get-ECSTaskDefinitions.ps1
function Get-ECSTaskDefinitions {
    param (
        [string]$Region,
        [hashtable]$Resources
    )
    Write-Host "Discovering ECS Task Definitions in $Region"
    $taskDefArns = Invoke-AWSCommand -Command "aws ecs list-task-definitions --output json" -Description "Task Definitions"
    if ($taskDefArns.taskDefinitionArns) {
        $families = @{}
        foreach ($taskDefArn in $taskDefArns.taskDefinitionArns) {
            $family = ($taskDefArn -split '/')[-1] -split ':' | Select-Object -First 1
            if (-not $families.ContainsKey($family)) {
                $families[$family] = $taskDefArn
            }
        }
        foreach ($family in $families.Keys) {
            $taskDef = Invoke-AWSCommand -Command "aws ecs describe-task-definition --task-definition `"$family`" --output json" -Description "Task Definition"
            if ($taskDef.taskDefinition) {
                $td = $taskDef.taskDefinition
                $Resources.ECSTaskDefinitions += @{
                    TaskDefinitionArn = $td.taskDefinitionArn
                    Family = $td.family
                    Revision = $td.revision
                    RequiresCompatibilities = $td.requiresCompatibilities -join ", "
                    Cpu = $td.cpu
                    Memory = $td.memory
                    Region = $Region
                }
            }
        }
    }
    Write-Host "ECS Task Definitions discovered in $Region"
}