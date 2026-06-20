function Get-Graph {
    $state = $Global:EKOSGraphState

    if (-not $state) {
        return @{
            nodes = @()
            edges = @()
        }
    }

    return @{
        nodes = $state.nodes.Values
        edges = $state.edges
    }
}