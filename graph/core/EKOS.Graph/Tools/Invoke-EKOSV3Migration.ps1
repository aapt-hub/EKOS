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

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path $PSScriptRoot -Parent

# =========================
# DISCOVERY
# =========================
function Get-EKOSFileMap {
    return Get-ChildItem -Path $Root -Recurse -Filter *.ps1 |
        ForEach-Object {
            [PSCustomObject]@{
                FullPath = $_.FullName
                Relative = $_.FullName.Replace($Root, "")
            }
        }
}

# =========================
# EXPECTED V3 STRUCTURE
# =========================
function Get-ExpectedModules {
    return @{
        "Engine/GraphCore.ps1" = "Core"
        "Storage/WAL.ps1" = "WAL"
        "Transaction/Commit-EKOSTransaction.ps1" = "Transaction"
        "Query/QueryPlanner.ps1" = "QueryPlanner"
        "Query/QueryOptimizer.ps1" = "QueryOptimizer"
        "Query/Invoke-EKOSQuery.ps1" = "QueryExecutor"
    }
}

# =========================
# ANALYSIS ENGINE
# =========================
function Compare-EKOSState {
    $files = Get-EKOSFileMap
    $expected = Get-ExpectedModules

    $report = @{
        Missing = @()
        Found = @()
        Orphaned = @()
    }

    foreach ($exp in $expected.Keys) {

        $match = $files | Where-Object { $_.Relative -like "*$exp" }

        if (-not $match) {
            $report.Missing += $exp
        }
        else {
            $report.Found += $exp
        }
    }

    foreach ($f in $files) {
        if (-not ($expected.Keys | Where-Object { $f.Relative -like "*$_" })) {
            $report.Orphaned += $f.Relative
        }
    }

    return $report
}

# =========================
# SAFE SCAFFOLDING (NO OVERWRITE)
# =========================
function New-EKOSStub {
    param([string]$RelativePath)

    $full = Join-Path $Root $RelativePath
    $dir = Split-Path $full -Parent

    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    if (-not (Test-Path $full)) {

        @"
# AUTO-GENERATED STUB (EKOS V3 MIGRATION)
# DO NOT EDIT CORE LOGIC HERE

function Initialize-Stub {
    Write-Host "[STUB] $RelativePath loaded"
}
"@ | Set-Content $full

        Write-Host "Created stub: $RelativePath"
    }
}

# =========================
# CONTRACT GENERATOR
# =========================
function New-EKOSContract {
    param($report)

    $contractPath = Join-Path $Root "EKOS.Runtime.contract.psd1"

    @"
@{
    Version = "3.1.0"

    GeneratedOn = "$(Get-Date)"

    Modules = @{
        Core = "Engine/GraphCore.ps1"
        WAL = "Storage/WAL.ps1"
        Transaction = "Transaction/Commit-EKOSTransaction.ps1"

        Query = @{
            Planner = "Query/QueryPlanner.ps1"
            Optimizer = "Query/QueryOptimizer.ps1"
            Executor = "Query/Invoke-EKOSQuery.ps1"
        }
    }

    MigrationReport = @{
        Missing = @($($report.Missing -join ','))
        Orphaned = @($($report.Orphaned -join ','))
    }
}
"@ | Set-Content $contractPath

    Write-Host "Contract generated: EKOS.Runtime.contract.psd1"
}

# =========================
# MAIN EXECUTION
# =========================
$report = Compare-EKOSState

Write-Host "`n=== EKOS MIGRATION REPORT ==="
$report | Format-List

# SAFE MODE: only scaffold missing modules
foreach ($m in $report.Missing) {
    New-EKOSStub $m
}

New-EKOSContract $report

Write-Host "`nMigration complete."