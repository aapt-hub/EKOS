function Commit-EKOSTransaction {
    param([string]$TxId)

    $tx = $Global:EKOS_Transactions[$TxId]

    if (-not $tx) {
        throw "Transaction not found: $TxId"
    }

    if ($tx.Status -ne "ACTIVE") {
        throw "Transaction not active"
    }

    # 1. Build projected graph state
    $projectedGraph = $Global:EKOS_Graph

    foreach ($op in $tx.Staging) {
        & $op.Command @op.Params
    }

    # 2. INTEGRITY CHECK (NEW v3.1 CORE)
    Invoke-EKOSIntegrityCheck -Graph $projectedGraph -Mode "PreCommit"

    # 3. WRITE WAL
    foreach ($op in $tx.Staging) {
        Write-EKOSWAL -TransactionId $TxId -Operation $op
    }

    # 4. COMMIT CONFIRMED
    $tx.Status = "COMMITTED"

    # 5. UPDATE INDEXES
    Update-EKOSIndex -Graph $projectedGraph

    return @{
        TxId   = $TxId
        Status = "COMMITTED"
        Ops    = $tx.Staging.Count
    }
}