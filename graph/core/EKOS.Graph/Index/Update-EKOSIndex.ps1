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

function Update-EKOSIndex {
    param([hashtable]$Graph)

    Initialize-EKOSIndex

    $Global:EKOS_Index.NodeById.Clear()
    $Global:EKOS_Index.EdgeByFrom.Clear()
    $Global:EKOS_Index.EdgeByTo.Clear()

    foreach ($n in $Graph.Nodes.Values) {
        $Global:EKOS_Index.NodeById[$n.Id] = $n
    }

    foreach ($e in $Graph.Edges) {

        if (-not $Global:EKOS_Index.EdgeByFrom[$e.From]) {
            $Global:EKOS_Index.EdgeByFrom[$e.From] = @()
        }

        if (-not $Global:EKOS_Index.EdgeByTo[$e.To]) {
            $Global:EKOS_Index.EdgeByTo[$e.To] = @()
        }

        $Global:EKOS_Index.EdgeByFrom[$e.From] += $e
        $Global:EKOS_Index.EdgeByTo[$e.To] += $e
    }
}