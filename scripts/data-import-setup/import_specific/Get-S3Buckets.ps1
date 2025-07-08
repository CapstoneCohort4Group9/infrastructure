# Get-S3Buckets.ps1
function Get-S3Buckets {
    param (
        [string]$Region,
        [hashtable]$Resources,
        [string]$AccountId
    )
    Write-Host "Discovering S3 Buckets in $Region for Account $AccountId"
    $buckets = Invoke-AWSCommand -Command "aws s3api list-buckets --output json" -Description "S3 Buckets" -AccountId $AccountId -Region  $Region #-RoleName $RoleName
    if ($buckets.Buckets) {
        foreach ($bucket in $buckets.Buckets) {
            $Resources.S3Buckets += @{
                BucketName = $bucket.Name
                CreationDate = $bucket.CreationDate
                Region = $Region
                AccountId = $AccountId
            }
            Write-Host "$($bucket.Name)"
        }
    } else {
        Write-Host "No S3 Buckets found or error accessing in $Region for Account $AccountId"
    }
    Write-Host "S3 Buckets discovered in $Region for Account $AccountId"
}