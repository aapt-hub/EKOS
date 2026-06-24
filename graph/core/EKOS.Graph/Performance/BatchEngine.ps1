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

# EKOS Batch Engine v3.1

$Global:EKOS_Batch = @{
    Enabled = $false
    Buffer = @()
}

function Begin-Batch {
    $Global:EKOS_Batch.Enabled = $true
    $Global:EKOS_Batch.Buffer = @()
}

function Add-BatchOp($op) {

    if ($Global:EKOS_Batch.Enabled) {
        $Global:EKOS_Batch.Buffer += $op
        return
    }

    Invoke-Expression $op
}

function End-Batch {

    foreach ($op in $Global:EKOS_Batch.Buffer) {
        Invoke-Expression $op
    }

    $Global:EKOS_Batch.Enabled = $false
    $Global:EKOS_Batch.Buffer = @()

    Write-Host "[EKOS.Graph] BATCH COMPLETE"
}