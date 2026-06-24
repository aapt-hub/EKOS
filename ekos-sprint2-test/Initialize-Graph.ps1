<#
AUTHOR:
Abner Pauneto

COPYRIGHT:
Copyright (c) 2026 Abner Pauneto

LICENSE:
Proprietary – All Rights Reserved

PROJECT:
EKOS

STATUS:
Private Development
#>

function Initialize-Graph {
    if (-not (Test-Path ".\nodes.json")) {
        @{ nodes = @() } | ConvertTo-Json -Depth 10 | Set-Content ".\nodes.json"
    }

    if (-not (Test-Path ".\edges.json")) {
        @{ edges = @() } | ConvertTo-Json -Depth 10 | Set-Content ".\edges.json"
    }

    Write-Host "Graph initialized"
}