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

# EKOS.Graph v3
# QueryOptimizer.psm1
# Pure deterministic query transformation layer

Set-StrictMode -Version Latest

# ===============================
# PUBLIC ENTRY POINT
# ===============================
function Invoke-QueryOptimizer {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Normalized
    )

    $optimized = $Normalized.Clone()

    # Step 1: Rewrite phase
    $optimized = Invoke-QueryRewrite -Query $optimized

    # Step 2: Filter pushdown
    $optimized = Invoke-FilterPushdown -Query $optimized

    # Step 3: Cost shaping hints
    $optimized = Invoke-CostShaping -Query $optimized

    # Step 4: Edge pre-validation pruning (SAFE ONLY)
    $optimized = Invoke-EdgePruning -Query $optimized

    # Attach optimizer metadata (for planner/debug only)
    $optimized["_optimizer"] = @{
        version = "3.0.0"
        timestamp = (Get-Date).ToString("o")
        stages = @("rewrite", "filter_pushdown", "cost_shaping", "edge_pruning")
    }

    return $optimized
}

# ===============================
# 1. QUERY REWRITE
# ===============================
function Invoke-QueryRewrite {
    param([hashtable]$Query)

    if (-not $Query.ContainsKey("text")) {
        return $Query
    }

    $text = $Query.text

    # Alias expansion map (extendable via config later)
    $aliases = @{
        "find"   = "search"
        "get"    = "query"
        "show"   = "query"
        "traverse" = "walk"
    }

    foreach ($key in $aliases.Keys) {
        $text = $text -replace "\b$key\b", $aliases[$key]
    }

    $Query.text = $text
    $Query._rewritten = $true

    return $Query
}

# ===============================
# 2. FILTER PUSHDOWN
# ===============================
function Invoke-FilterPushdown {
    param([hashtable]$Query)

    if (-not $Query.ContainsKey("filters")) {
        return $Query
    }

    # Normalize filters into execution-ready structure
    $filters = @()

    foreach ($f in $Query.filters) {
        if ($null -ne $f -and $f -ne "") {
            $filters += $f
        }
    }

    $Query.filters = $filters
    $Query._filters_pushed = $true

    return $Query
}

# ===============================
# 3. COST SHAPING (TRAVERSAL STRATEGY)
# ===============================
function Invoke-CostShaping {
    param([hashtable]$Query)

    $cost = @{
        traversal = "bfs"
        fanout_limit = 100
        depth_limit = 10
    }

    # Heuristics (simple but stable v3 baseline)
    if ($Query.text -match "deep|chain|path") {
        $cost.traversal = "dfs"
        $cost.depth_limit = 20
    }

    if ($Query.text -match "fast|quick|simple") {
        $cost.fanout_limit = 25
    }

    if ($Query.type -eq "Search") {
        $cost.traversal = "bfs"
    }

    $Query._cost_model = $cost
    $Query._cost_shaped = $true

    return $Query
}

# ===============================
# 4. EDGE PRUNING (SAFE ONLY)
# ===============================
function Invoke-EdgePruning {
    param([hashtable]$Query)

    if (-not $Query.ContainsKey("edges")) {
        return $Query
    }

    $seen = @{}
    $pruned = @()

    foreach ($edge in $Query.edges) {

        if ($null -eq $edge.from -or $null -eq $edge.to) {
            continue
        }

        $signature = "$($edge.from)->$($edge.to)"

        # duplicate prevention (safe deterministic rule)
        if ($seen.ContainsKey($signature)) {
            continue
        }

        # basic invalid edge rule
        if ($edge.from -eq $edge.to) {
            continue
        }

        $seen[$signature] = $true
        $pruned += $edge
    }

    $Query.edges = $pruned
    $Query._edges_pruned = $true

    return $Query
}

# ===============================
# EXPORTS
# ===============================
Export-ModuleMember -Function Invoke-QueryOptimizer