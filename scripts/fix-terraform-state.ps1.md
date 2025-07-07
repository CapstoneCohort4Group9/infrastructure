# Remove and Re-import (Cleanest)

```
powershell
```

    # Step 1: Check what's in the state
    ..\scripts\fix-terraform-state.ps1 -Action check

    # Step 2: Remove the secrets from Terraform state (won't delete from AWS)
    ..\scripts\fix-terraform-state.ps1 -Action remove

    # Step 3: Re-import them properly
    ..\scripts\import-existing-secrets.ps1

    # Step 4: Verify
    terraform plan
