# ============================================================
# EKOS v3.3 GRAPH QUERY ENGINE
# Path: C:\Repos\EKOS\graph\query-engine.ps1
# ============================================================

Write-Host "EKOS Query Engine starting..." -ForegroundColor Cyan

# ============================================================
# LOAD GRAPH
# ============================================================

$graphPath = "C:\Repos\EKOS\graph"
$nodesFile = "$graphPath\nodes.json"
$edgesFile = "$graphPath\edges.json"

if (!(Test-Path $nodesFile)) { throw "Missing nodes.json at $nodesFile" }
if (!(Test-Path $edgesFile)) { throw "Missing edges.json at $edgesFile" }

$nodes = Get-Content $nodesFile -Raw | ConvertFrom-Json
$edges = Get-Content $edgesFile -Raw | ConvertFrom-Json

if (-not $nodes) { $nodes = @() }
if (-not $edges) { $edges = @() }

# ============================================================
# BASIC NODE ACCESS
# ============================================================

function Get-NodeById {
    param($id)
    return $nodes | Where-Object { $_.id -eq $id }
}

function Get-OutgoingEdges {
    param($nodeId)
    return $edges | Where-Object { $_.from -eq $nodeId }
}

function Get-IncomingEdges {
    param($nodeId)
    return $edges | Where-Object { $_.to -eq $nodeId }
}

# ============================================================
# MATCH QUERY
# ============================================================

function Match-Node {
    param(
        $id = $null,
        $type = $null,
        $labelContains = $null
    )

    $result = $nodes

    if ($id) {
        $result = $result | Where-Object { $_.id -eq $id }
    }

    if ($type) {
        $result = $result | Where-Object { $_.type -eq $type }
    }

    if ($labelContains) {
        $result = $result | Where-Object { $_.label -like "*$labelContains*" }
    }

    return $result
}

# ============================================================
# NEIGHBOURS (1-HOP)
# ============================================================

function Get-Neighbours {
    param($nodeId)

    $out = Get-OutgoingEdges $nodeId | ForEach-Object { $_.to }
    $in  = Get-IncomingEdges $nodeId | ForEach-Object { $_.from }

    return ($out + $in | Select-Object -Unique) |
        ForEach-Object { Get-NodeById $_ }
}

# ============================================================
# PATH FINDING (BFS)
# ============================================================

function Find-Path {
    param(
        $startId,
        $endId,
        $maxDepth = 5
    )

    $queue = @()
    $visited = @{}

    $queue += ,@($startId, @($startId))

    while ($queue.Count -gt 0) {

        $current = $queue[0]
        $queue = $queue[1..($queue.Count - 1)]

        $nodeId = $current[0]
        $path = $current[1]

        if ($path.Count -gt $maxDepth) { continue }
        if ($nodeId -eq $endId) { return $path }

        if ($visited[$nodeId]) { continue }
        $visited[$nodeId] = $true

        foreach ($n in (Get-Neighbours $nodeId)) {
            if (-not $n) { continue }

            $queue += ,@($n.id, ($path + $n.id))
        }
    }

    return $null
}

# ============================================================
# EXPLAIN PATH
# ============================================================

function Explain-Path {
    param($path)

    Write-Host "`n=== PATH EXPLANATION ===`n" -ForegroundColor Yellow

    for ($i = 0; $i -lt $path.Count - 1; $i++) {

        $from = Get-NodeById $path[$i]
        $to   = Get-NodeById $path[$i + 1]

        $edge = $edges | Where-Object {
            ($_.from -eq $from.id -and $_.to -eq $to.id) -or
            ($_.from -eq $to.id -and $_.to -eq $from.id)
        } | Select-Object -First 1

        if ($edge) {
            Write-Host "$($from.id) → $($to.id)" -ForegroundColor Green
            Write-Host "  Type: $($edge.type)" -ForegroundColor Gray
            Write-Host "  Weight: $($edge.weight)" -ForegroundColor Gray
        }
    }
}

# ============================================================
# PUBLIC API
# ============================================================

function Query-EKOS {
    param(
        [string]$mode,
        [string]$a,
        [string]$b
    )

    switch ($mode) {

        "match" {
            return Match-Node -id $a
        }

        "neighbours" {
            return Get-Neighbours $a
        }

        "path" {
            return Find-Path $a $b
        }

        "explain" {
            $path = Find-Path $a $b
            if ($path) {
                Explain-Path $path
            } else {
                Write-Host "No path found."
            }
        }

        default {
            Write-Host "Use: match | neighbours | path | explain"
        }
    }
}

# ============================================================
# READY
# ============================================================

Write-Host "EKOS Query Engine READY" -ForegroundColor Green