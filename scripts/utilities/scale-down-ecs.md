Here's a PowerShell script to set all ECS service desired counts to 0:This PowerShell script will:

## Features:
- **Scale down all ECS services** across all clusters to 0 tasks
- **Safety features**: Dry run mode, confirmation prompts, detailed logging
- **Flexible**: Can target specific clusters or all clusters
- **Error handling**: Continues processing even if some services fail
- **Status reporting**: Shows current vs target desired counts

## Before executing the .ps1 check the identtiy
```powershell
aws sts get-caller-identity

#if the identity is not what you are after than set the correct identity by
$env:AWS_PROFILE = "hopjetair"

#recheck if you are in the correct aws account and region
aws sts get-caller-identity

```

## Usage Examples:

**1. Dry run (see what would be changed):**
```powershell
.\scale-down-ecs.ps1 -WhatIf
```

**2. Scale down all services with confirmation:**
```powershell
.\scale-down-ecs.ps1
```

**3. Scale down all services without confirmation:**
```powershell
.\scale-down-ecs.ps1 -Force
```

**4. Scale down services in specific cluster:**
```powershell
.\scale-down-ecs.ps1 -ClusterName "my-cluster" -Force
```

**5. Different region:**
```powershell
.\scale-down-ecs.ps1 -Region "us-west-2" -Force
```

## Safety Features:
- **WhatIf mode**: Shows what would be changed without making changes
- **Confirmation prompt**: Asks before making changes (unless `-Force` is used)
- **Skip inactive services**: Only updates services that are ACTIVE and have desired count > 0
- **Detailed logging**: Shows current state and results for each service

The script will help you quickly scale down all your ECS services, which is useful for cost savings during development or maintenance windows.