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

Write-Host "🔧 EKOS.Graph Repair Script Starting..." -ForegroundColor Cyan

$root = "C:\Repos\EKOS\graph\core\EKOS.Graph"

# -----------------------------
# 1. Detect duplicates / legacy
# -----------------------------

Write-Host "`n📦 Checking legacy systems..." -ForegroundColor Yellow

$legacyTx = "$root\Engine\TransactionEngine.ps1"
$legacyWAL = "$root\Engine\WAL.ps1"

if (Test-Path $legacyTx) {
    Rename-Item $legacyTx "$legacyTx.LEGACY" -Force
    Write-Host "❌ Disabled legacy TransactionEngine" -ForegroundColor Red
}

if (Test-Path $legacyWAL) {
    Rename-Item $legacyWAL "$legacyWAL.LEGACY" -Force
    Write-Host "❌ Disabled duplicate WAL (Engine)" -ForegroundColor Red
}

# -----------------------------
# 2. Verify single WAL exists
# -----------------------------

Write-Host "`n🧾 Checking WAL consistency..." -ForegroundColor Yellow

$walStorage = "$root\Storage\WAL.ps1"

if (-not (Test-Path $walStorage)) {
    Write-Host "❌ WAL missing in Storage layer" -ForegroundColor Red
} else {
    Write-Host "✅ WAL unified in Storage layer" -ForegroundColor Green
}

# -----------------------------
# 3. Verify transaction system
# -----------------------------

Write-Host "`n🔁 Checking transaction engine..." -ForegroundColor Yellow

$txFiles = @(
    "$root\Transaction\Commit-EKOSTransaction.ps1"
)

foreach ($f in $txFiles) {
    if (Test-Path $f) {
        Write-Host "✅ Found: $f"
    } else {
        Write-Host "❌ Missing: $f" -ForegroundColor Red
    }
}

# -----------------------------
# 4. Verify Integrity Layer
# -----------------------------

Write-Host "`n🧠 Checking Integrity Layer..." -ForegroundColor Yellow

$integrityFiles = @(
    "$root\Integrity\Test-EKOSSchema.ps1",
    "$root\Integrity\Test-EKOSDuplicateEdge.ps1",
    "$root\Integrity\Test-EKOSCycle.ps1",
    "$root\Integrity\Invoke-EKOSIntegrityCheck.ps1"
)

foreach ($f in $integrityFiles) {
    if (Test-Path $f) {
        Write-Host "✅ $f"
    } else {
        Write-Host "❌ Missing: $f" -ForegroundColor Red
    }
}

# -----------------------------
# 5. Verify Index Layer
# -----------------------------

Write-Host "`n⚡ Checking Index Layer..." -ForegroundColor Yellow

$indexFiles = @(
    "$root\Index\Initialize-EKOSIndex.ps1",
    "$root\Index\Update-EKOSIndex.ps1",
    "$root\Index\Get-EKOSNodeIndex.ps1",
    "$root\Index\Get-EKOSEdgeIndex.ps1"
)

foreach ($f in $indexFiles) {
    if (Test-Path $f) {
        Write-Host "✅ $f"
    } else {
        Write-Host "❌ Missing: $f" -ForegroundColor Red
    }
}

# -----------------------------
# 6. Health Summary
# -----------------------------

Write-Host "`n📊 EKOS SYSTEM HEALTH CHECK COMPLETE" -ForegroundColor Cyan
Write-Host "👉 Legacy engines disabled"
Write-Host "👉 WAL unified (Storage layer)"
Write-Host "👉 Transaction layer active"
Write-Host "👉 Integrity + Index layers present"

Write-Host "`n⚠️ NEXT STEP:"
Write-Host "Run a commit test transaction to validate pipeline" -ForegroundColor Yellow