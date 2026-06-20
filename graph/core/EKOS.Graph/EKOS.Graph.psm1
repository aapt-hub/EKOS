# EKOS.Graph.psm1
# ===================================================
# EKOS Graph Engine - Stable Sprint 2 Core Module
# ===================================================

$base = $PSScriptRoot

Write-Host "`n[EKOS.Graph] BOOTSTRAP START`n"

# ---------------------------------------------------
# GLOBAL STATE (single source of truth)
# ---------------------------------------------------
if (-not $Global:EKOS_Graph) {
    $Global:EKOS_Graph = @{
        nodes = @{}
        edges = @()
    }
}

# ---------------------------------------------------
# LOAD ENGINE LAYER
# ---------------------------------------------------
. "$base\Engine\GraphState.ps1"
. "$base\Engine\NodeEngine.ps1"
. "$base\Engine\EdgeEngine.ps1"

# ---------------------------------------------------
# LOAD VALIDATION LAYER
# ---------------------------------------------------
. "$base\Validation\ValidationEngine.ps1"

# ---------------------------------------------------
# LOAD STORAGE LAYER
# ---------------------------------------------------
. "$base\Storage\Load-Graph.ps1"
. "$base\Storage\Save-Graph.ps1"

# ---------------------------------------------------
# API LAYER (DEFINED HERE - NOT IN SEPARATE FILES)
# ---------------------------------------------------

function Add-Node {
    param(
        [string]$Name,
        [string]$Type
    )

    Assert-NodeName $Name

    $result = Add-NodeCore $Name $Type

    if ($result.success) {
        Save-Graph
    }

    return $result
}

function Add-Edge {
    param(
        [string]$From,
        [string]$To,
        [string]$Relation
    )

    Assert-EdgeIntegrity $From $To

    $result = Add-EdgeCore $From $To $Relation

    if ($result.success) {
        Save-Graph
    }

    return $result
}

function Get-Graph {

    if (-not $Global:EKOS_Graph) {
        return @{
            nodes = @()
            edges = @()
        }
    }

    return @{
        nodes = $Global:EKOS_Graph.nodes.Values
        edges = $Global:EKOS_Graph.edges
    }
}

# ---------------------------------------------------
# EXPORT PUBLIC API
# ---------------------------------------------------
Export-ModuleMember -Function @(
    "Add-Node",
    "Add-Edge",
    "Get-Graph"
)

Write-Host "`n[EKOS.Graph] BOOTSTRAP COMPLETE`n"