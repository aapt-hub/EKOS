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

<#
EKOS.Graph v3 Bootstrap (WAL-FIRST ARCHITECTURE)

Key fixes:
- Removed PersistenceLayer dependency
- WAL is single source of truth
- No duplicate module loading
- Deterministic initialization order
- Safer failure reporting
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# =========================
# GLOBAL CONTEXT
# =========================
$script:EKOS = [ordered]@{
    Version = "3.0.0"
    Root    = $PSScriptRoot | Split-Path -Parent
    Loaded  = @{}
    Errors  = @()
}

# =========================
# LOGGING
# =========================
function Write-EKOSLog {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp][$Level] $Message"
}

# =========================
# SAFE IMPORTER
# =========================
function Import-EKOSScript {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [string]$Name
    )

    try {
        if (-not (Test-Path $Path)) {
            throw "Missing file: $Path"
        }

        . $Path

        if ($Name) {
            $script:EKOS.Loaded[$Name] = $true
        }

        Write-EKOSLog "Loaded: $Path"
    }
    catch {
        $script:EKOS.Errors += $_.Exception.Message
        Write-EKOSLog "FAILED: $Path -> $($_.Exception.Message)" "ERROR"
        throw
    }
}

# =========================
# STRUCTURE VALIDATION
# =========================
function Assert-EKOSStructure {

    $required = @(
        "$($script:EKOS.Root)\Engine",
        "$($script:EKOS.Root)\Storage",
        "$($script:EKOS.Root)\Query",
        "$($script:EKOS.Root)\Transaction"
    )

    foreach ($r in $required) {
        if (-not (Test-Path $r)) {
            throw "Missing required directory: $r"
        }
    }

    Write-EKOSLog "Structure validation passed"
}

# =========================
# CORE INITIALIZATION
# =========================
function Initialize-EKOSCore {

    Write-EKOSLog "Initializing EKOS.Graph v$($script:EKOS.Version)"

    Assert-EKOSStructure

    # =========================
    # 1. CORE ENGINE
    # =========================
    Import-EKOSScript "$($script:EKOS.Root)\Engine\GraphCore.ps1" "Core"

    # =========================
    # 2. STORAGE LAYER (WAL-FIRST)
    # =========================

    $walPath  = "$($script:EKOS.Root)\Storage\WAL.ps1"
    $loadPath = "$($script:EKOS.Root)\Storage\Load-Graph.ps1"
    $savePath = "$($script:EKOS.Root)\Storage\Save-Graph.ps1"

    Import-EKOSScript $walPath  "WAL"
    Import-EKOSScript $loadPath "StorageLoad"
    Import-EKOSScript $savePath "StorageSave"

    Write-EKOSLog "Storage layer initialized (WAL-based)"

    # =========================
    # 3. TRANSACTION ENGINE
    # =========================
    Import-EKOSScript "$($script:EKOS.Root)\Transaction\Commit-EKOSTransaction.ps1" "Transaction"

   # =========================
# QUERY LAYER (CURRENT REAL STRUCTURE)
# =========================

$queryEngine   = "$($script:EKOS.Root)\Query\QueryEngine.ps1"
$queryOptimizer = "$($script:EKOS.Root)\Query\QueryOptimizer.psm1"

if (Test-Path $queryEngine) {
    Import-EKOSScript $queryEngine "QueryEngine"
} else {
    Write-EKOSLog "Missing QueryEngine.ps1" "ERROR"
}

if (Test-Path $queryOptimizer) {
    Import-EKOSScript $queryOptimizer "QueryOptimizer"
} else {
    Write-EKOSLog "Missing QueryOptimizer.psm1" "ERROR"
}

# Legacy compatibility mapping
$script:EKOS.Loaded["QueryPlanner"] = "REDIRECTED_TO_QueryEngine"
$script:EKOS.Loaded["QueryExecutor"] = "REDIRECTED_TO_QueryEngine"
}

# =========================
# SERVICE INITIALIZATION
# =========================
function Initialize-EKOSServices {

    Write-EKOSLog "Initializing runtime services..."

    if (Get-Command Initialize-WAL -ErrorAction SilentlyContinue) {
        Initialize-WAL
        Write-EKOSLog "WAL runtime initialized"
    }

    if (Get-Command Initialize-TransactionEngine -ErrorAction SilentlyContinue) {
        Initialize-TransactionEngine
        Write-EKOSLog "Transaction engine initialized"
    }

    if (Get-Command Initialize-QuerySystem -ErrorAction SilentlyContinue) {
        Initialize-QuerySystem
        Write-EKOSLog "Query system initialized"
    }

    Write-EKOSLog "Runtime services ready"
}

# =========================
# HEALTH CHECK
# =========================
function Test-EKOSHealth {

    Write-EKOSLog "Running health checks..."

    $checks = @(
        @{ Name = "Core"; Test = { $script:EKOS.Loaded["Core"] } },
        @{ Name = "WAL"; Test = { $script:EKOS.Loaded["WAL"] } },
        @{ Name = "Storage"; Test = { $script:EKOS.Loaded["StorageLoad"] -and $script:EKOS.Loaded["StorageSave"] } },
        @{ Name = "Query"; Test = { $script:EKOS.Loaded["QueryExecutor"] } }
    )

    foreach ($c in $checks) {
        if (-not (& $c.Test)) {
            throw "Health check failed: $($c.Name)"
        }

        Write-EKOSLog "OK: $($c.Name)"
    }

    Write-EKOSLog "System health OK"
}

# =========================
# MAIN BOOTSTRAP
# =========================
try {

    Initialize-EKOSCore
    Initialize-EKOSServices
    Test-EKOSHealth

    Write-EKOSLog "EKOS.Graph BOOT SUCCESS"

    return [pscustomobject]@{
        Status = "READY"
        Version = $script:EKOS.Version
        LoadedModules = $script:EKOS.Loaded.Keys
        Errors = $script:EKOS.Errors
    }
}
catch {
    Write-EKOSLog "BOOT FAILED: $($_.Exception.Message)" "FATAL"

    return [pscustomobject]@{
        Status = "FAILED"
        Error = $_.Exception.Message
        LoadedModules = $script:EKOS.Loaded.Keys
    }
}