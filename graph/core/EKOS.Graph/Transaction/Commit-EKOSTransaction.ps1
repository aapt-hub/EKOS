<#
EKOS.Graph v3 - Transaction Engine (Fixed Execution Model)

Fixes:
- Removes invalid @op.Params splatting
- Normalizes transaction ops
- Adds safe execution boundary
- Prevents runtime expression-binding errors
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# =========================
# TRANSACTION CORE
# =========================

function Initialize-TransactionEngine {
    Write-Host "[INFO] Transaction Engine initialized"
}

# =========================
# OP NORMALIZATION
# =========================
function Normalize-EKOSTransactionOp {
    param(
        [Parameter(Mandatory)]
        $Op
    )

    # Ensure command exists
    if (-not $Op.Command) {
        throw "Transaction Op missing Command"
    }

    # Normalize params into hashtable (safe splatting format)
    $params = @{}

    if ($Op.Params) {
        foreach ($key in $Op.Params.Keys) {
            $params[$key] = $Op.Params[$key]
        }
    }

    return [pscustomobject]@{
        Command = $Op.Command
        Params  = $params
    }
}

# =========================
# EXECUTION ENGINE
# =========================
function Invoke-EKOSTransaction {
    param(
        [Parameter(Mandatory)]
        [array]$Ops
    )

    $results = @()

    foreach ($op in $Ops) {

        try {
            # Normalize before execution
            $normalized = Normalize-EKOSTransactionOp $op

            $command = $normalized.Command
            $params  = $normalized.Params

            if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
                throw "Command not found: $command"
            }

            # SAFE EXECUTION (FIX FOR YOUR ERROR)
            $result = & $command @params

            $results += $result
        }
        catch {
            throw "Transaction failed: $($_.Exception.Message)"
        }
    }

    return $results
}

# =========================
# COMMIT ENTRY POINT
# =========================
function Commit-EKOSTransaction {
    param(
        [Parameter(Mandatory)]
        [array]$Operations
    )

    Write-Host "[INFO] Committing EKOS transaction..."

    $result = Invoke-EKOSTransaction -Ops $Operations

    Write-Host "[INFO] Transaction committed successfully"

    return $result
}