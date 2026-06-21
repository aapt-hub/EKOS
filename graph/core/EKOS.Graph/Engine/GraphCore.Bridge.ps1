# =====================================================
# EKOS.Graph v3.1 - GRAPH CORE BRIDGE LAYER
# Single Entry Execution Gateway
# =====================================================

function Invoke-EKOSGraphCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,

        [Parameter(Mandatory = $true)]
        [hashtable]$Params,

        [switch]$UseTransaction
    )

    try {

        # -----------------------------------------
        # TRANSACTION MODE (STRICT PATH)
        # -----------------------------------------
        if ($UseTransaction) {

            if (-not (Get-Command Begin-EKOSTransaction -ErrorAction SilentlyContinue)) {
                throw "[EKOS.BRIDGE] Begin-EKOSTransaction not available"
            }

            if (-not (Get-Command Invoke-EKOSCommand -ErrorAction SilentlyContinue)) {
                throw "[EKOS.BRIDGE] Invoke-EKOSCommand not available"
            }

            if (-not (Get-Command Commit-EKOSTransaction -ErrorAction SilentlyContinue)) {
                throw "[EKOS.BRIDGE] Commit-EKOSTransaction not available"
            }

            $tx = Begin-EKOSTransaction

            $result = Invoke-EKOSCommand -TxId $tx -Command $Command -Params $Params

            $commit = Commit-EKOSTransaction -TxId $tx

            return @{
                TransactionId = $tx
                Result         = $result
                Commit         = $commit
                Status         = "SUCCESS"
            }
        }

        # -----------------------------------------
        # DIRECT MODE (LEGACY FALLBACK ONLY)
        # -----------------------------------------
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "[EKOS.BRIDGE] Command not found: $Command"
        }

        $directResult = & $Command @Params

        return @{
            Result = $directResult
            Mode   = "DIRECT"
        }

    }
    catch {
        return @{
            Status  = "FAILED"
            Error   = $_.Exception.Message
            Command = $Command
        }
    }
}

# =====================================================
# FORCE MODULE VISIBILITY (CRITICAL FIX)
# =====================================================

Set-Item -Path Function:\Invoke-EKOSGraphCommand -Value ${function:Invoke-EKOSGraphCommand}