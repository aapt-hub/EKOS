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