$root = (Get-Location).Path

$systemGraphPath = "C:\Repos\EKOS\ekos.system.graph.json"

if (!(Test-Path $systemGraphPath)) {
    Write-Host "ERROR: System graph not found. Run classification first."
    exit 1
}

$graph = Get-Content $systemGraphPath | ConvertFrom-Json

# ==============================
# TRANSACTION MODEL (SIMULATION ONLY)
# ==============================

function New-TransactionPlan {

    param($nodes)

    $plan = foreach ($n in $nodes) {

        # Example rule: detect unstable nodes
        $risk = 0

        if ($n.type -eq "unknown") { $risk += 50 }
        if ($n.extension -eq "") { $risk += 10 }
        if ($n.path -match "\\legacy\\|\\temp\\") { $risk += 30 }

        [PSCustomObject]@{
            nodeId = $n.nodeId
            path = $n.path
            type = $n.type
            riskScore = $risk
            action = if ($risk -gt 50) { "REVIEW" } else { "ACCEPT" }
        }
    }

    return $plan
}

$plan = New-TransactionPlan $graph

$out = Join-Path $root "ekos.transaction.plan.json"

$plan | ConvertTo-Json -Depth 6 | Set-Content $out -Encoding UTF8

# ==============================
# SUMMARY
# ==============================

$review = ($plan | Where-Object { $_.action -eq "REVIEW" }).Count
$accept = ($plan | Where-Object { $_.action -eq "ACCEPT" }).Count

Write-Host "TRANSACTION PLAN GENERATED"
Write-Host "ACCEPT: $accept"
Write-Host "REVIEW: $review"
Write-Host "OUTPUT: $out"