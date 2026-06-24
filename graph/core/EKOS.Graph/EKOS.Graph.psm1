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

# =====================================================
# EKOS.Graph v3.1 - STABLE MODULE CORE
# Unified Execution + Transaction Safe Loader
# =====================================================

$ErrorActionPreference = "Stop"

# -----------------------------
# CORE ENGINE
# -----------------------------
. "$PSScriptRoot\Engine\GraphCore.ps1"

# -----------------------------
# BRIDGE LAYER
# -----------------------------
. "$PSScriptRoot\Engine\GraphCore.Bridge.ps1"

# -----------------------------
# TRANSACTION ENGINE (SINGLE SOURCE OF TRUTH)
# -----------------------------
# "$PSScriptRoot\Engine\TransactionEngine.ps1"

# -----------------------------
# STORAGE / WAL
# -----------------------------
. "$PSScriptRoot\Storage\WAL.ps1"

# -----------------------------
# INDEX ENGINE
# -----------------------------
. "$PSScriptRoot\Index\Initialize-EKOSIndex.ps1"
. "$PSScriptRoot\Index\Update-EKOSIndex.ps1"

# =====================================================
# MODULE INITIALIZATION
# =====================================================

Initialize-EKOSGraph

Write-Host "[EKOS.Graph] MODULE LOADED (STABLE v3 CORE)" -ForegroundColor Green

# =====================================================
# EXPORTS (CRITICAL)
# =====================================================

Export-ModuleMember -Function `
    Add-Node, `
    Add-Edge, `
    Begin-EKOSTransaction, `
    Commit-EKOSTransaction, `
    Invoke-EKOSCommand, `
    Invoke-EKOSGraphCommand, `
    Invoke-EKOSQuery, `
    Invoke-EKOSQueryOptimizer, `
    Initialize-EKOSGraph