<#
FILE: C:\repos\ekos\graph\query-engine.ps1

EKOS Sprint 1 - Query Engine (READ ONLY)

PURPOSE:
Performs deterministic 1-hop traversal of the graph.

RULES:
- Read-only access
- Exact match only
- No semantic search
- No inference
- No multi-hop traversal
#>

function Query-EKOS {
    param(
        [string]$nodeId
    )

    # Load graph using absolute script path
    $nodes = (Get-Content "$PSScriptRoot\nodes.json" | ConvertFrom-Json).nodes
    $edges = (Get-Content "$PSScriptRoot\edges.json" | ConvertFrom-Json).edges

    # Validate node exists
    if ($nodes.id -notcontains $nodeId) {
        return @{
            nodes = @()
            edges = @()
        } | ConvertTo-Json -Depth 10
    }

    # 1-hop traversal only (outgoing edges)
    $relatedEdges = $edges | Where-Object { $_.from -eq $nodeId }

    $relatedNodes = @()

    foreach ($edge in $relatedEdges) {
        $relatedNodes += $edge.to
    }

    # Deterministic output
    return @{
        nodes = $relatedNodes
        edges = $relatedEdges
    } | ConvertTo-Json -Depth 10
}