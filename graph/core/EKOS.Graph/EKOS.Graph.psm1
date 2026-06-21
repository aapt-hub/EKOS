$ErrorActionPreference = "Stop"

# ENGINE
. "$PSScriptRoot\Engine\GraphState.ps1"
. "$PSScriptRoot\Engine\TransactionEngine.ps1"
. "$PSScriptRoot\Engine\WAL.ps1"

# API
. "$PSScriptRoot\API\Add-Node.ps1"
. "$PSScriptRoot\API\Add-Edge.ps1"
. "$PSScriptRoot\API\Get-Graph.ps1"
. "$PSScriptRoot\API\Traverse-Graph.ps1"

function Initialize-EKOSGraph {
    Initialize-GraphState
    Initialize-WAL
    Write-Host "[EKOS.Graph] INITIALIZED"
}

Export-ModuleMember -Function *

. "$PSScriptRoot\Engine\WAL.ps1"