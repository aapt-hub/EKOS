# EKOS Query Engine (STABLE LOAD)

$optimizerModule = Join-Path $PSScriptRoot "QueryOptimizer.psm1"

if (-not (Test-Path $optimizerModule)) {
    throw "Missing QueryOptimizer.psm1 at $optimizerModule"
}

# IMPORT MODULE PROPERLY (NOT DOT-SOURCING)
Import-Module $optimizerModule -Force -Scope Global

function Invoke-EKOSQuery {
    param(
        [hashtable]$Query
    )

    if (-not (Get-Command Invoke-EKOSQueryOptimizer -ErrorAction SilentlyContinue)) {
        throw "Invoke-EKOSQueryOptimizer failed to load"
    }

    return Invoke-EKOSQueryOptimizer -Query $Query
}