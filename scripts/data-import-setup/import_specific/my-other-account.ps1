# use-profile.ps1

# Save the current profile (if any)
$originalProfile = $env:AWS_PROFILE

# Set the new profile
$env:AWS_PROFILE = "hopjetair"
Write-Host "Switched to AWS profile: $env:AWS_PROFILE"

# Run your AWS CLI commands here
aws sts get-caller-identity
aws s3 ls

# Restore the original profile
if ($null -ne $originalProfile) {
    $env:AWS_PROFILE = $originalProfile
    Write-Host "Restored original AWS profile: $env:AWS_PROFILE"
} else {
    Remove-Item Env:AWS_PROFILE -ErrorAction SilentlyContinue
    Write-Host "Cleared AWS profile, using default credentials"
}
