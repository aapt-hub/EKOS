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

function Test-EKOSCycle {
    param([hashtable]$Graph)

    $visited = @{}
    $stack   = @{}

    function Visit($nodeId) {

        if ($stack[$nodeId]) {
            throw "Cycle detected at node: $nodeId"
        }

        if ($visited[$nodeId]) { return }

        $visited[$nodeId] = $true
        $stack[$nodeId]   = $true

        foreach ($edge in $Graph.Edges | Where-Object { $_.From -eq $nodeId }) {
            Visit $edge.To
        }

        $stack[$nodeId] = $false
    }

    foreach ($node in $Graph.Nodes.Keys) {
        Visit $node
    }

    return $true
}