$Global:EKOS_TX = $null

function Begin-EKOSTransaction {
    $Global:EKOS_TX = @{
        snapshot = ($Global:EKOS_Graph | ConvertTo-Json -Depth 20)
        active   = $true
    }

    Write-Host "[EKOS.Graph] TX START"
}

function Commit-EKOSTransaction {
    $Global:EKOS_TX = $null
    Write-Host "[EKOS.Graph] TX COMMIT"
}

function Rollback-EKOSTransaction {
    if ($Global:EKOS_TX) {
        $Global:EKOS_Graph = ($Global:EKOS_TX.snapshot | ConvertFrom-Json -Depth 20)
        $Global:EKOS_TX = $null
        Write-Host "[EKOS.Graph] TX ROLLBACK"
    }
}