```
powershell
```

    # First time initialization
    cd terraform
    ..\scripts\terraform-init.ps1

    # This will:
    # 1. Auto-detect your AWS account ID
    # 2. Initialize Terraform with the correct backend
    # 3. Create a backend-config.hcl file for future use

    # Future initializations
    terraform init -backend-config="backend-config.hcl"

✅ Tips for Success
Make sure backend-config.hcl is in the same directory where you're running the command.

If you're using multiple config files (e.g., for different environments), you can pass multiple -backend-config flags:

```
bash
```

    terraform init \
    -backend-config="env/dev.hcl" \
    -backend-config="common.hcl"


## How to Use the Updated Script:

```powershell
# First time initialization
.\scripts\setup-terraform-init.ps1

# If you're migrating from old state location (ecr/ to infrastructure/)
.\scripts\setup-terraform-init.ps1 -MigrateState

# If you want to reconfigure (fresh start)
.\scripts\setup-terraform-init.ps1 -Reconfigure

# If you're switching AWS accounts
.\scripts\setup-terraform-init.ps1 -AccountId "123456789012" -Reconfigure
```

