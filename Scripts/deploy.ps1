$root_path = Split-Path $PSScriptRoot -Parent
Import-Module "$root_path/Scripts/PS-Library"


function New-Environment() {

    #region obtain ito hub name
    $iot_hubs = az iot hub list | ConvertFrom-Json | Sort-Object -Property id

    Write-Host
    Write-Host "Choose an IoT hub to use from this list (using its Index):"
    for ($index = 0; $index -lt $iot_hubs.Count; $index++) {
        Write-Host
        Write-Host "$($index + 1): $($iot_hubs[$index].id)"
    }
    while ($true) {
        $option = Read-Host -Prompt ">"
        try {
            if ([int]$option -ge 1 -and [int]$option -le $iot_hubs.Count) {
                break
            }
        }
        catch {
            Write-Host "Invalid index '$($option)' provided."
        }
        Write-Host "Choose from the list using an index between 1 and $($iot_hubs.Count)."
    }

    $iot_hub = $iot_hubs[$option - 1].name
    $resource_group = $iot_hubs[$option - 1].resourceGroup

    $twin_tag = "sqlEdge=true"
    $target_condition = "tags.$($twin_tag)"
    #endregion

    # update IoT edge deployment with stream analytics job details
    $mmsql_sa_password = "SuperSecretP@ssw0rd!"
    $deployment_template = "$root_path/sqledge.template.json"
    $deployment_manifest = "$root_path/sqledge.manifest.json"

    (Get-Content -Path $deployment_template -Raw) | ForEach-Object {
        $_ `
            -replace '__MSSQL_SA_PASSWORD__', $mmsql_sa_password `
            -replace '__MSSQL_PACKAGE__', "" `
            -replace '__ASA_JOB_INFO__', $edge_manifest.twin.content.'properties.desired'.ASAJobInfo
    } | Set-Content -Path $deployment_manifest

    Write-Host
    Write-Host "Creating SQL edge deployment"

    $priority = Get-date -Format 'yyMMddHHmm'
    az iot edge deployment create --layered -d "sqlEdge-$priority" --pri $priority -n $iot_hub --tc "$target_condition" --content $deployment_manifest
    
    Write-Host
    Write-Host -Foreground Yellow "NOTE: You must update your IoT edge device(s) twin by adding the tag `"$twin_tag`" to apply the new deployment"
    #endregion
}

New-Environment