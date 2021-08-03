function Publish-EdgeJob(
    [string]$subscription_id,
    [string]$resource_group,
    [string]$location,
    [string]$job_name
)
{
    if (!$subscription_id)
    {
        $subscription_id = az account show --query id -o tsv
    }
    if (!$location)
    {
        $location = az group show -n $resource_group --query location -o tsv
    }

    $token = az account get-access-token --resource-type arm --query accessToken -o tsv
    $secure_token = ConvertTo-SecureString $token -AsPlainText -Force
    
    if ($location.StartsWith("usdod") -or $location.StartsWith("usgov"))
    {
        $base_uri = "https://management.usgovcloudapi.net"
    }
    else
    {
        $base_uri = "https://management.azure.com"
    }

    $publish_uri = "$($base_uri)/subscriptions/$($subscription_id)/resourceGroups/$($resource_group)/providers/Microsoft.StreamAnalytics/streamingjobs/$($job_name)/publishedgepackage?api-version=2017-04-01-preview"
    $publish_response = Invoke-WebRequest $publish_uri `
        -Method POST `
        -Authentication Bearer -Token $secure_token

    $count = 5
    do
    {
        Start-Sleep -Seconds 60
        Write-Host "Waiting for publish response..."
        
        $package_response = Invoke-WebRequest $publish_response.Headers.Location[0] `
            -Method Get `
            -Authentication Bearer -Token $secure_token
        
        $count--
    } while (!$package_response -or ($package_response.StatusCode -ne 200 -and $count -gt 0))

    if ($package_response.StatusCode -ne 200)
    {
        Write-Host -ForegroundColor Red "Failed to publish ASA edge job."
        Write-Host -ForegroundColor Red ($package_response | Out-String)

        return $null
    }

    $content = $package_response.Content | ConvertFrom-Json -Depth 15
    $manifest = $content.manifest | ConvertFrom-Json -Depth 15

    return $manifest
}

function Set-ASAEdgeJobConnectionString(
    [string]$blob_url
)
{
    # create temp folder to download job
    $temp_path = "$($env:TEMP)\$((New-Guid).Guid)"
    $zip_path = "$temp_path\zip"
    Write-Host "Working directory: $zip_path"
    New-Item -Path $zip_path -ItemType Directory -ErrorAction Stop | Out-Null

    # parse blob URL
    $regex_expression = "https:\/\/(.*)\.blob\.core\.windows\.net\/([a-z0-9-]+)\/(.*)\/([a-zA-Z0-9]+\.zip)\?(.*)"
    if ($blob_url -match $regex_expression)
    {
        $storage_account = $Matches[1]
        $storage_container = $Matches[2]
        $blob_path = $Matches[3]
        $blob_name = $Matches[4]
        $blob_token = $Matches[5]

        Write-Host
        Write-Host "Blob details:"
        Write-Host "Storage Account: $storage_account"
        Write-Host "Storage Container: $storage_container"
        Write-Host "Blob path: $blob_path"
        Write-Host "Blob Name: $blob_name"
    }
    else
    {
        Write-Error "Unable to parse blob URI. Aborting."
        return $null
    }

    # Download and unzip blob
    Invoke-RestMethod -Uri $blob_url -OutFile "$temp_path\$blob_name"
    Expand-Archive -LiteralPath "$temp_path\$blob_name" -DestinationPath $zip_path

    # Update connection string
    (Get-Content -Path "$zip_path\EdgeJobDefinition.txt" -Raw) | ForEach-Object {
        $_ -replace 'Encrypt=True', 'TrustServerCertificate=True;Encrypt=True'
    } | Set-Content -Path "$zip_path\EdgeJobDefinition.txt"

    # zip package
    Compress-Archive -Path "$zip_path\EdgeJobDefinition.txt" -Update -DestinationPath "$temp_path\$blob_name"

    return @{
        "Account" = $storage_account
        "Container" = $storage_container
        "Path" = $blob_path
        "Name" = $blob_name
        "LocalPath" = "$temp_path\$blob_name"
    }
}