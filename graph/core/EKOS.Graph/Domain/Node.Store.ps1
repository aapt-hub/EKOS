# Node.Store.ps1
# EKOS Graph Domain Layer - Node State

if (-not $Global:EKOS_Graph) {
    $Global:EKOS_Graph = @{
        nodes = @()
        edges = @()
    }
}