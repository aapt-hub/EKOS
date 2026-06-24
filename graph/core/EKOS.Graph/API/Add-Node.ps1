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

function Add-Node {
    param(
        [string]$Name,
        [string]$Type,
        [switch]$Replay
    )

    $state = Get-GraphState

    if (-not $state.nodes) {
        throw "[EKOS.Graph] STATE CORRUPTED"
    }

    if ($state.nodes.ContainsKey($Name)) {
        Write-Host "[EKOS.Graph] NODE EXISTS: $Name"
        return
    }

    $state.nodes[$Name] = @{
        name    = $Name
        type    = $Type
        created = Get-Date
    }

    if (-not $Replay) {
        Write-WAL "AddNode" @{
            name = $Name
            type = $Type
        }
    }

    Write-Host "[EKOS.Graph] NODE ADDED: $Name"
}