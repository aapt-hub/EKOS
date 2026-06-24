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

function Test-EKOSDuplicateEdge {
    param([hashtable]$Graph)

    $seen = @{}

    foreach ($edge in $Graph.Edges) {
        $key = "$($edge.From)->$($edge.To)"

        if ($seen[$key]) {
            throw "Duplicate edge detected: $key"
        }

        $seen[$key] = $true
    }

    return $true
}