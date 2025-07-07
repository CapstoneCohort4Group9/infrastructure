# Get-EC2Instances.ps1
function Get-EC2Instances {
    param (
        [string]$Region,
        [hashtable]$Resources
    )
    Write-Host "Discovering EC2 Instances in $Region"
    $instances = Invoke-AWSCommand -Command "aws ec2 describe-instances --query 'Reservations[].Instances[?State.Name != ''terminated'']' --output json" -Description "EC2 Instances"
    if ($instances) {
        foreach ($instance in $instances) {
            $name = if ($instance.PSObject.Properties['Tags'] -and ($instance.Tags | Where-Object { $_.Key -eq "Name" })) {
                ($instance.Tags | Where-Object { $_.Key -eq "Name" }).Value
            } else {
                "Unnamed"
            }
            $Resources.EC2Instances += @{
                InstanceId = $instance.InstanceId
                Name = $name
                Type = $instance.InstanceType
                State = $instance.State.Name
                VpcId = $instance.VpcId
                SubnetId = $instance.SubnetId
                Region = $Region
            }
        }
    }
    Write-Host "EC2 Instances discovered in $Region"
}