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

# EKOS.Graph v3.2.1 - Transaction Safe Index Engine

$Global:EKOS_Index = @{
    ById = @{}
    ByType = @{}
    OutEdges = @{}
    InEdges = @{}
}

function Initialize-IndexEngine {

    $Global:EKOS_Index.ById = @{}
    $Global:EKOS_Index.ByType = @{}
    $Global:EKOS_Index.OutEdges = @{}
    $Global:EKOS_Index.InEdges = @{}

    Write-Host "[EKOS.Index] INITIALIZED"
}

# -----------------------------
# TRANSACTION BUFFER SUPPORT
# -----------------------------

function Ensure-TxIndexBuffer {
    param($Tx)

    if (-not $Tx.PendingIndex) {
        $Tx.PendingIndex = @{
            Nodes = @()
            Edges = @()
        }
    }
}

# -----------------------------
# BUFFER OPERATIONS
# -----------------------------

function Buffer-NodeIndex {
    param($Tx, $Node)

    Ensure-TxIndexBuffer $Tx
    $Tx.PendingIndex.Nodes += $Node
}

function Buffer-EdgeIndex {
    param($Tx, $Edge)

    Ensure-TxIndexBuffer $Tx
    $Tx.PendingIndex.Edges += $Edge
}

# -----------------------------
# COMMIT FLUSH (ONLY PLACE INDEX WRITES HAPPEN)
# -----------------------------

function Commit-IndexBuffer {
    param($Tx)

    if (-not $Tx.PendingIndex) { return }

    foreach ($n in $Tx.PendingIndex.Nodes) {
        Index-Node $n
    }

    foreach ($e in $Tx.PendingIndex.Edges) {
        Index-Edge $e
    }

    $Tx.PendingIndex = $null
}

# -----------------------------
# CORE INDEX BUILDERS
# -----------------------------

function Index-Node {
    param($Node)

    $Global:EKOS_Index.ById[$Node.Id] = $Node

    if (-not $Global:EKOS_Index.ByType[$Node.Type]) {
        $Global:EKOS_Index.ByType[$Node.Type] = @()
    }

    if ($Global:EKOS_Index.ByType[$Node.Type] -notcontains $Node.Id) {
        $Global:EKOS_Index.ByType[$Node.Type] += $Node.Id
    }
}

function Index-Edge {
    param($Edge)

    # Outgoing
    if (-not $Global:EKOS_Index.OutEdges[$Edge.From]) {
        $Global:EKOS_Index.OutEdges[$Edge.From] = @()
    }

    if ($Global:EKOS_Index.OutEdges[$Edge.From] -notcontains $Edge.To) {
        $Global:EKOS_Index.OutEdges[$Edge.From] += $Edge.To
    }

    # Incoming
    if (-not $Global:EKOS_Index.InEdges[$Edge.To]) {
        $Global:EKOS_Index.InEdges[$Edge.To] = @()
    }

    if ($Global:EKOS_Index.InEdges[$Edge.To] -notcontains $Edge.From) {
        $Global:EKOS_Index.InEdges[$Edge.To] += $Edge.From
    }
}

# -----------------------------
# LOOKUPS
# -----------------------------

function Get-NodeById {
    param($Id)
    return $Global:EKOS_Index.ById[$Id]
}

function Get-NodesByType {
    param($Type)
    return $Global:EKOS_Index.ByType[$Type]
}

function Get-OutNeighbors {
    param($NodeId)
    return $Global:EKOS_Index.OutEdges[$NodeId]
}

function Get-InNeighbors {
    param($NodeId)
    return $Global:EKOS_Index.InEdges[$NodeId]
}

# -----------------------------
# SAFE REBUILD
# -----------------------------

function Rebuild-Index {

    Initialize-IndexEngine

    foreach ($n in $Global:EKOS_Graph.Nodes.Values) {
        Index-Node $n
    }

    foreach ($e in $Global:EKOS_Graph.Edges.Values) {
        Index-Edge $e
    }

    Write-Host "[EKOS.Index] REBUILT"
}