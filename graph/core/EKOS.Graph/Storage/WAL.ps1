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