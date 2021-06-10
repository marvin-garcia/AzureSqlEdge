$root_path = Split-Path $PSScriptRoot -Parent

$iot_hubs = az iot hub list | ConvertFrom-Json | Sort-Object -Property id

Write-Host
Write-Host "Choose an IoT hub to use from this list (using its Index):"

for ($index = 0; $index -lt $iot_hubs.Count; $index++)
{
    Write-Host
    Write-Host "$($index + 1): $($iot_hubs[$index].id)"
}
while ($true)
{
    $option = Read-Host -Prompt ">"
    try
    {
        if ([int]$option -ge 1 -and [int]$option -le $iot_hubs.Count)
        {
            break
        }
    }
    catch
    {
        Write-Host "Invalid index '$($option)' provided."
    }
    Write-Host "Choose from the list using an index between 1 and $($iot_hubs.Count)."
}

$iot_hub_name = $iot_hubs[$option - 1].name

# simulated temperature sensor
$priority = (Get-Date -Format 'yyMMddhhmm')
$id = "sqledge-$priority"
$target_condition = "tags.sqlEdge=true"
$content = "$root_path/SqlEdgeSolution/sqledge.manifest.json"

az iot edge deployment create `
    --layered `
    --hub-name $iot_hub_name `
    --deployment $id `
    --pri $priority `
    --tc $target_condition `
    --content $content

Write-Host
Write-Host -ForegroundColor Yellow "Deployment priority: $($priority)"
Write-Host -ForegroundColor Yellow "NOTE: You must update your IoT edge device twin with '$target_condition' to apply this deployment."