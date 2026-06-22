$systemPath = "C:\Repos\EKOS\ekos.system.graph.json"

if (!(Test-Path $systemPath)) {
    Write-Host "ERROR: system graph not found"
    exit 1
}

$nodes = Get-Content $systemPath | ConvertFrom-Json

# ==============================
# BUILD SIMPLE DEPENDENCY MODEL
# ==============================

function Get-GroupKey($path) {

    $p = $path.ToLower()

    if ($p -match "\\graph\\") { return "GRAPH_LAYER" }
    if ($p -match "\\graphcompiler\\") { return "COMPILER_LAYER" }
    if ($p -match "\\tools\\") { return "TOOLS_LAYER" }
    if ($p -match "\\patterns\\|\\standards\\|\\architectures\\") { return "ARCH_LAYER" }
    if ($p -match "\\runbooks\\") { return "OPS_LAYER" }
    if ($p -match "\\templates\\") { return "TEMPLATE_LAYER" }

    return "CORE"
}

# ==============================
# VALIDATION ENGINE
# ==============================

$validated = $nodes | ForEach-Object {

    $group = Get-GroupKey $_.path

    $impact = switch ($group) {
        "COMPILER_LAYER" { 90 }
        "GRAPH_LAYER"    { 80 }
        "CORE"           { 70 }
        "TOOLS_LAYER"    { 50 }
        "ARCH_LAYER"     { 40 }
        "OPS_LAYER"      { 30 }
        "TEMPLATE_LAYER" { 20 }
        default          { 10 }
    }

    $level =
        if ($impact -ge 80) { "CRITICAL" }
        elseif ($impact -ge 60) { "HIGH" }
        elseif ($impact -ge 40) { "MEDIUM" }
        else { "LOW" }

    [PSCustomObject]@{
        nodeId = $_.nodeId
        path = $_.path
        type = $_.type
        group = $group
        impactScore = $impact
        impactLevel = $level
    }
}

$out = "C:\Repos\EKOS\graph\tools\ekos.transaction.validation.json"

$validated | ConvertTo-Json -Depth 6 | Set-Content $out

# ==============================
# SUMMARY
# ==============================

$summary = $validated | Group-Object impactLevel | Select-Object Name, Count

Write-Host "VALIDATION COMPLETE"
Write-Host "OUTPUT: $out"
$summary