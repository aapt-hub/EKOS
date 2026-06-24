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

$Global:EKOS_Graph = $null

function Initialize-GraphState {
    $Global:EKOS_Graph = @{
        nodes   = @{}
        edges   = @()
        version = "v3"
    }

    Write-Host "[EKOS.Graph] STATE INITIALIZED"
}

function Get-GraphState {
    return $Global:EKOS_Graph
}

function Set-GraphState {
    param([hashtable]$State)
    $Global:EKOS_Graph = $State
}