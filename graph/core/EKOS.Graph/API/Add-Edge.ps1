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

function Add-Edge {
    param(
        [string]$From,
        [string]$To,
        [string]$Relation,
        [switch]$Replay
    )

    $state = Get-GraphState

    if (-not $state.nodes.ContainsKey($From) -or -not $state.nodes.ContainsKey($To)) {
        throw "[EKOS.Graph] INVALID EDGE: missing node"
    }

    $edge = @{
        from     = $From
        to       = $To
        relation = $Relation
    }

    $state.edges += $edge

    if (-not $Replay) {
        Write-WAL "AddEdge" $edge
    }

    Write-Host "[EKOS.Graph] EDGE: $From -> $To ($Relation)"
}