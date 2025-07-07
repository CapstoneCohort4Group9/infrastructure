# Get-ALBs.ps1
function Get-ALBs {
    param (
        [string]$Region,
        [hashtable]$Resources
    )
    Write-Host "Discovering Application Load Balancers in $Region"
    $albs = Invoke-AWSCommand -Command "aws elbv2 describe-load-balancers --output json" -Description "Load Balancers"
    if ($albs.LoadBalancers) {
        foreach ($alb in $albs.LoadBalancers | Where-Object { $_.Type -eq "application" }) {
            $Resources.ALBs += @{
                LoadBalancerArn = $alb.LoadBalancerArn
                LoadBalancerName = $alb.LoadBalancerName
                DNSName = $alb.DNSName
                Scheme = $alb.Scheme
                VpcId = $alb.VpcId
                State = $alb.State.Code
                Type = $alb.Type
                Region = $Region
            }
        }
    }
    Write-Host "Application Load Balancers discovered in $Region"
}