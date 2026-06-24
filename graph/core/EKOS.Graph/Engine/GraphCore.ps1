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

# EKOS Graph Core v3.2.1 (Index-Consistent Version)

function Initialize-EKOSGraph {

    $Global:EKOS_Graph = @{
        Nodes = @{}
        Edges = @{}
        Version = 0
    }

    Initialize-IndexEngine

    Write-Host "[EKOS.Graph] INITIALIZED"
}

function Add-Node {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id,

        [Parameter(Mandatory = $true)]
        [string]$Type
    )

    $tx = $Global:EKOS_Context.CurrentTransaction
    if (-not $tx) {
        throw "[EKOS.Graph] No active transaction"
    }

    Acquire-EKOSLock -Id $Id -TxId $tx.Id

    $tx.Locks += $Id

    $node = @{
        Id   = $Id
        Type = $Type
    }

    # Write to main graph store
    $Global:EKOS_Graph.Nodes[$Id] = $node

    # IMPORTANT: buffer only (NOT direct indexing)
    Buffer-NodeIndex -Tx $tx -Node $node

    $Global:EKOS_Graph.Version++
}

function Add-Edge {
    param(
        [Parameter(Mandatory = $true)]
        [string]$From,

        [Parameter(Mandatory = $true)]
        [string]$To,

        [Parameter(Mandatory = $false)]
        [string]$Type = "rel"
    )

    $tx = $Global:EKOS_Context.CurrentTransaction
    if (-not $tx) {
        throw "[EKOS.Graph] No active transaction"
    }

    $key = "$From->$To"

    Acquire-EKOSLock -Id $key -TxId $tx.Id

    $tx.Locks += $key

    $edge = @{
        From = $From
        To   = $To
        Type = $Type
    }

    # Write to main graph store
    $Global:EKOS_Graph.Edges[$key] = $edge

    # IMPORTANT: buffer only (NOT direct indexing)
    Buffer-EdgeIndex -Tx $tx -Edge $edge

    $Global:EKOS_Graph.Version++
}

function Get-Graph {
    return $Global:EKOS_Graph
}