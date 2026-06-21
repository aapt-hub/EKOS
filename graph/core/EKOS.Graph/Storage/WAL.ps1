# EKOS WAL v3.1

$Global:EKOS_WAL = @()

function Write-WAL {
    param($Tx)

    $Global:EKOS_WAL += @{
        TxId = $Tx.Id
        Locks = $Tx.Locks
        Timestamp = Get-Date
    }
}