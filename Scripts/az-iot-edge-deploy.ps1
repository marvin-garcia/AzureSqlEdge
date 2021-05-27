$root_path = Split-Path $PSScriptRoot -Parent

Write-Host
Write-Host "Provide the IoT Hub name to create the deployment"
$hub_name = Read-Host -Prompt ">"

$priority = (Get-Date -Format 'yyMMddhhmm')
$id = "sqledge-$priority"
$target_condition = "tags.sqlEdge=true"
$content = "$root_path/EdgeSolution/deployment.template.json"

az iot edge deployment create `
    --layered `
    --hub-name $hub_name `
    --deployment $id `
    --pri $priority `
    --tc $target_condition `
    --content $content

Write-Host
Write-Host -ForegroundColor Yellow "NOTE: You must update your IoT edge device twin with '$target_condition' to apply this deployment."