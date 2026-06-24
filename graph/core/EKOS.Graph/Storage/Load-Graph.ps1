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

function Load-Graph {
    $path = "$PSScriptRoot\..\Data\graph.json"

    if (Test-Path $path) {
        $Global:EKOS_Graph = Get-Content $path | ConvertFrom-Json -Depth 10
    }
}