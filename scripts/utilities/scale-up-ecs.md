# ECS Service Scale Up Script

This PowerShell script will scale up all ECS services that are currently at 0 tasks to 1 task each.

## Features:
- **Scale up ECS services** across all clusters from 0 to 1 task
- **Safety features**: Dry run mode, confirmation prompts, detailed logging
- **Flexible**: Can target specific clusters or all clusters
- **Error handling**: Continues processing even if some services fail
- **Status reporting**: Shows current vs target desired counts
- **Smart filtering**: Only targets services that are currently at 0 tasks

## Prerequisites

### Check AWS Identity
Before executing the script, verify you're using the correct AWS identity:

```powershell
aws sts get-caller-identity

# If the identity is not correct, set the appropriate AWS profile
$env:AWS_PROFILE = "your-profile-name"

# Recheck if you are in the correct AWS account and region
aws sts get-caller-identity
```

### Required Permissions
Ensure your AWS credentials have the following ECS permissions:
- `ecs:ListClusters`
- `ecs:ListServices`
- `ecs:DescribeServices`
- `ecs:UpdateService`

## Usage Examples

### 1. Dry run (see what would be changed)
```powershell
.\scale-up-ecs.ps1 -WhatIf
```
This will show you which services would be scaled up without making any changes.

### 2. Scale up all services with confirmation
```powershell
.\scale-up-ecs.ps1
```
This will prompt for confirmation before scaling up services.

### 3. Scale up all services without confirmation
```powershell
.\scale-up-ecs.ps1 -Force
```
This will immediately scale up all services that are currently at 0 tasks.

### 4. Scale up services in specific cluster
```powershell
.\scale-up-ecs.ps1 -ClusterName "my-cluster" -Force
```
This will only process services in the specified cluster.

### 5. Different region
```powershell
.\scale-up-ecs.ps1 -Region "us-west-2" -Force
```
This will operate in the specified AWS region.

### 6. Combined parameters
```powershell
.\scale-up-ecs.ps1 -Region "eu-west-1" -ClusterName "production-cluster" -WhatIf
```
This will show what would be scaled up in a specific cluster and region.

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-Region` | String | "us-east-1" | AWS region to operate in |
| `-ClusterName` | String | null | Specific cluster to target (optional) |
| `-WhatIf` | Switch | false | Dry run mode - shows changes without applying them |
| `-Force` | Switch | false | Skip confirmation prompts |

## Safety Features

### Dry Run Mode
- Use `-WhatIf` to see exactly what would be changed
- No actual modifications are made to your ECS services
- Perfect for validation before running the actual command

### Confirmation Prompt
- By default, the script asks for confirmation before making changes
- Shows a summary of all services that will be scaled up
- Use `-Force` to skip confirmations (useful for automation)

### Smart Filtering
- Only targets services that are currently at 0 desired count
- Skips services that are already running (desired count > 0)
- Skips inactive services
- Provides clear status messages for each service

### Error Handling
- Continues processing even if individual services fail
- Provides detailed error messages
- Shows final summary of successes and failures

## Output Example

```
ECS Service Scale Up Script
Region: us-east-1

Processing cluster: my-cluster
  Found 3 service(s)
    Service: web-service
      Current desired count: 0
      Status: ACTIVE
    Service: api-service
      Current desired count: 1
      Already running (1 tasks) - skipping
    Service: worker-service
      Current desired count: 0
      Status: ACTIVE

============================================================
SUMMARY
============================================================
Services to update: 2
  my-cluster/web-service : 0 -> 1
  my-cluster/worker-service : 0 -> 1

This will scale up 2 service(s) to 1 task each.
Are you sure you want to continue? (y/N): y

Updating services...
Updating my-cluster/web-service...
  Success
Updating my-cluster/worker-service...
  Success

============================================================
OPERATION COMPLETE
============================================================
Successfully updated: 2 service(s)

Note: Services are being scaled up. It may take a few minutes for tasks to fully start.
You can monitor progress with: aws ecs list-services --cluster CLUSTER-NAME
```

## Use Cases

This script is particularly useful for:

### Development Environments
- **Morning startup**: Scale up all services after overnight shutdown
- **Post-maintenance**: Restore services after maintenance windows
- **Environment restoration**: Quickly restore a scaled-down environment

### Cost Management
- **Scheduled scaling**: Use with task schedulers for automated daily startup
- **Environment management**: Restore environments that were scaled down for cost savings

### Disaster Recovery
- **Service restoration**: Quickly restore services after an incident
- **Failover scenarios**: Scale up services in alternative regions

## Monitoring

After running the script, you can monitor the scaling progress:

```powershell
# Check service status
aws ecs describe-services --cluster CLUSTER-NAME --services SERVICE-NAME

# List all services in a cluster
aws ecs list-services --cluster CLUSTER-NAME

# Monitor task status
aws ecs list-tasks --cluster CLUSTER-NAME --service-name SERVICE-NAME
```

## Complementary Scripts

This script works perfectly with the scale-down script:
- Use `scale-down-ecs.ps1` to scale services to 0 (cost savings)
- Use `scale-up-ecs.ps1` to scale services back to 1 (restore operations)

## Troubleshooting

### Common Issues

**AWS CLI not configured:**
```
Error: Unable to locate credentials
```
Solution: Run `aws configure` or set up AWS credentials

**Insufficient permissions:**
```
Error: User is not authorized to perform: ecs:UpdateService
```
Solution: Ensure your AWS user/role has the required ECS permissions

**Service update limits:**
```
Error: Service cannot be updated more than 10 times in 10 minutes
```
Solution: Wait and retry, or use `-WhatIf` to verify changes before running

**Invalid cluster name:**
```
Error: Cluster not found
```
Solution: Verify the cluster name and region are correct