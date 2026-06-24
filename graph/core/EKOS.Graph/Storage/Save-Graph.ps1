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

function Save-Graph {
    $Global:EKOS_Graph | ConvertTo-Json -Depth 10 |
        Set-Content "$PSScriptRoot\..\Data\graph.json"
}