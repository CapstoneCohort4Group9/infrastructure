# PowerShell script to check deployment status

param(
    [Parameter(Mandatory=$false)]
    [string]$Region = "us-east-1",
    
    [Parameter(Mandatory=$false)]
    [string]$ClusterName = "hopjetair-cluster"
)

Write-Host "Checking HopJetAir Infrastructure Status" -ForegroundColor Green
Write-Host "=" * 50 -ForegroundColor Gray

# Set AWS region
$env:AWS_DEFAULT_REGION = $Region

# Function to check service status
function Get-ServiceStatus {
    param([string]$ServiceName)
    
    $service = aws ecs describe-services `
        --cluster $ClusterName `
        --services $ServiceName `
        --query "services[0]" `
        --output json | ConvertFrom-Json
    
    if ($service) {
        $status = @{
            Name = $service.serviceName
            DesiredCount = $service.desiredCount
            RunningCount = $service.runningCount
            PendingCount = $service.pendingCount
            Status = $service.status
            LastDeployment = $service.deployments[0].status
        }
        
        # Color code the output
        $color = "Green"
        if ($service.runningCount -ne $service.desiredCount) {
            $color = "Yellow"
        }
        if ($service.runningCount -eq 0) {
            $color = "Red"
        }
        
        Write-Host "  $($status.Name): " -NoNewline
        Write-Host "$($status.RunningCount)/$($status.DesiredCount) running" -ForegroundColor $color
        
        if ($status.PendingCount -gt 0) {
            Write-Host "    Pending: $($status.PendingCount)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  $ServiceName: Not found" -ForegroundColor Red
    }
}

# Check ECS Cluster
Write-Host "`n[ECS Cluster]" -ForegroundColor Cyan
$cluster = aws ecs describe-clusters `
    --clusters $ClusterName `
    --query "clusters[0]" `
    --output json | ConvertFrom-Json

if ($cluster) {
    Write-Host "  Name: $($cluster.clusterName)" -ForegroundColor White
    Write-Host "  Status: $($cluster.status)" -ForegroundColor White
    Write-Host "  Active Services: $($cluster.activeServicesCount)" -ForegroundColor White
    Write-Host "  Running Tasks: $($cluster.runningTasksCount)" -ForegroundColor White
} else {
    Write-Host "  Cluster not found!" -ForegroundColor Red
    exit 1
}

# Check ECS Services
Write-Host "`n[ECS Services]" -ForegroundColor Cyan
$services = @(
    "frontend-api",
    "langgraph-api",
    "intent-api",
    "sentiment-api",
    "non-ai-api",
    "rag-api"
)

foreach ($service in $services) {
    Get-ServiceStatus -ServiceName $service
}

# Check ALB
Write-Host "`n[Application Load Balancer]" -ForegroundColor Cyan
$albs = aws elbv2 describe-load-balancers `
    --names "hopjetair-alb" `
    --query "LoadBalancers[0]" `
    --output json 2>$null | ConvertFrom-Json

if ($albs) {
    Write-Host "  Name: $($albs.LoadBalancerName)" -ForegroundColor White
    Write-Host "  DNS: $($albs.DNSName)" -ForegroundColor Green
    Write-Host "  State: $($albs.State.Code)" -ForegroundColor White
    Write-Host "  URL: http://$($albs.DNSName)" -ForegroundColor Yellow
} else {
    Write-Host "  ALB not found" -ForegroundColor Red
}

# Check Target Group Health
Write-Host "`n[Target Group Health]" -ForegroundColor Cyan
$targetGroups = aws elbv2 describe-target-groups `
    --names "hopjetair-alb-frontend-tg" `
    --query "TargetGroups[0]" `
    --output json 2>$null | ConvertFrom-Json

if ($targetGroups) {
    $health = aws elbv2 describe-target-health `
        --target-group-arn $targetGroups.TargetGroupArn `
        --query "TargetHealthDescriptions" `
        --output json | ConvertFrom-Json
    
    $healthy = ($health | Where-Object { $_.TargetHealth.State -eq "healthy" }).Count
    $total = $health.Count
    
    $color = if ($healthy -eq $total) { "Green" } elseif ($healthy -gt 0) { "Yellow" } else { "Red" }
    Write-Host "  Frontend targets: $healthy/$total healthy" -ForegroundColor $color
} else {
    Write-Host "  Target group not found" -ForegroundColor Red
}

# Check RDS
Write-Host "`n[RDS PostgreSQL]" -ForegroundColor Cyan
$rds = aws rds describe-db-instances `
    --db-instance-identifier "hopjetair-postgres" `
    --query "DBInstances[0]" `
    --output json 2>$null | ConvertFrom-Json

if ($rds) {
    Write-Host "  Instance: $($rds.DBInstanceIdentifier)" -ForegroundColor White
    Write-Host "  Status: $($rds.DBInstanceStatus)" -ForegroundColor $(if($rds.DBInstanceStatus -eq "available"){"Green"}else{"Yellow"})
    Write-Host "  Engine: $($rds.Engine) $($rds.EngineVersion)" -ForegroundColor White
    Write-Host "  Endpoint: $($rds.Endpoint.Address):$($rds.Endpoint.Port)" -ForegroundColor White
} else {
    Write-Host "  RDS instance not found" -ForegroundColor Red
}

# Check Service Discovery
Write-Host "`n[Service Discovery]" -ForegroundColor Cyan
$namespaces = aws servicediscovery list-namespaces `
    --query "Namespaces[?Name=='hopjetair.local']" `
    --output json | ConvertFrom-Json

if ($namespaces) {
    $namespace = $namespaces[0]
    Write-Host "  Namespace: $($namespace.Name)" -ForegroundColor White
    
    $services = aws servicediscovery list-services `
        --filters "Name=NAMESPACE_ID,Values=$($namespace.Id)" `
        --query "Services" `
        --output json | ConvertFrom-Json
    
    Write-Host "  Registered services: $($services.Count)" -ForegroundColor White
    foreach ($svc in $services) {
        Write-Host "    - $($svc.Name)" -ForegroundColor Gray
    }
} else {
    Write-Host "  Service discovery namespace not found" -ForegroundColor Red
}

# Summary
Write-Host "`n[Summary]" -ForegroundColor Green
Write-Host "=" * 50 -ForegroundColor Gray

if ($albs) {
    Write-Host "`nFrontend URL: " -NoNewline
    Write-Host "http://$($albs.DNSName)" -ForegroundColor Cyan
    Write-Host "`nTo test the frontend:" -ForegroundColor Yellow
    Write-Host "curl http://$($albs.DNSName)" -ForegroundColor White
}

Write-Host "`nTo view logs:" -ForegroundColor Yellow
Write-Host "aws logs tail /ecs/<service-name> --follow" -ForegroundColor White

Write-Host "`nTo update a service:" -ForegroundColor Yellow
Write-Host "aws ecs update-service --cluster $ClusterName --service <service-name> --force-new-deployment" -ForegroundColor White