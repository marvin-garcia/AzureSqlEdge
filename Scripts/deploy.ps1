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


    $priority = (az iot edge deployment list -n $iot_hub `
        | ConvertFrom-Json `
        | Sort-Object -Property 'priority' -Descending)[0].priority
    
    #region create OPC deployment
    $opc_publisher_deployment_manifest = "$root_path/EdgeSolution/opc.manifest.json"
    
    Write-Host
    $option = Read-Host -Prompt "Deploy OPC Publisher? [Y/N] (Default N)"

    if ($option -eq 'y') {
        Write-Host
        Write-Host "Creating OPC publisher edge deployment"

        $priority += 1
        az iot edge deployment create `
            --layered `
            -d "opcpub-$priority" `
            --pri $priority `
            -n $iot_hub `
            --tc "$target_condition" `
            --content $opc_publisher_deployment_manifest
    }
    #endregion

    #region create SQL edge deployment
    Write-Host
    $option = Read-Host -Prompt "Deploy SQL edge? [Y/N] (Default N)"

    if ($option -eq 'y') {
        $mmsql_sa_password = "SuperSecretP@ssw0rd!"
        $sql_edge_deployment_template = "$root_path/EdgeSolution/sqledge.template.json"
        $sql_edge_deployment_manifest = "$root_path/EdgeSolution/sqledge.manifest.json"

        (Get-Content -Path $sql_edge_deployment_template -Raw) | ForEach-Object {
            $_ `
                -replace '__MSSQL_SA_PASSWORD__', $mmsql_sa_password `
                -replace '__MSSQL_PACKAGE__', "" `
                -replace '__ASA_JOB_INFO__', $edge_manifest.twin.content.'properties.desired'.ASAJobInfo
        } | Set-Content -Path $sql_edge_deployment_manifest

        Write-Host
        Write-Host "Creating Azure SQL edge deployment"

        $priority += 1
        az iot edge deployment create `
            --layered `
            -n $iot_hub `
            -d "sqledge-$priority" `
            --pri $priority `
            --tc "tags.sqlEdge=true" `
            --content $sql_edge_deployment_manifest
    }
    #endregion

    #region create SQL scorer deployment
    Write-Host
    $option = Read-Host -Prompt "Deploy SQL scorer? [Y/N] (Default N)"

    if ($option -eq 'y') {

        $sql_scorer_deployment_manifest = "$root_path/EdgeSolution/sql-scorer.manifest.json"

        Write-Host
        $option = Read-Host -Prompt "Build Docker image? [Y/N] (Default N)"

        if ($option -eq 'y') {
            Write-Host
            Write-Host "Building Docker image"

            $image_tag = Get-date -Format 'yyMMddHHmm'
            $image = "marvingarcia/az-sql-edge-scorer:$image_tag"
            $dockerfile = "$root_path/EdgeSolution/modules/Scorer/Dockerfile.amd64"
            $docker_scope = "$root_path/EdgeSolution/modules/Scorer/"
            docker build -t $image -f $dockerfile $docker_scope
            docker push $image

            Write-Host
            Write-Host "Creating deployment manifest"

            $sql_scorer_deployment_template = "$root_path/EdgeSolution/sql-scorer.template.json"
            
            (Get-Content -Path $sql_scorer_deployment_template -Raw) | ForEach-Object {
                $_ `
                    -replace '__IMAGE__', $image
            } | Set-Content -Path $sql_scorer_deployment_manifest
        }

        Write-Host
        Write-Host "Creating Azure SQL scorer deployment"

        $priority += 1
        az iot edge deployment create `
            --layered `
            -n $iot_hub `
            -d "sqlscorer-$priority" `
            --pri $priority `
            --tc "tags.sqlEdge=true" `
            --content $sql_scorer_deployment_manifest
    }
    #endregion

    Write-Host
    Write-Host -Foreground Yellow "NOTE: You must update your IoT edge device(s) twin by adding the tag `"$twin_tag`" to apply the new deployment"
    #endregion
}

New-Environment