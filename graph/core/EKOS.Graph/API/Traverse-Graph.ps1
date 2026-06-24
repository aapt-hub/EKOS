function Traverse-Graph {
    param(
        [string]$StartNode,
        [ValidateSet("DFS", "BFS")]
        [string]$Mode = "DFS"
    )

    $state = Get-GraphState

    if (-not $state.nodes.ContainsKey($StartNode)) {
        throw "[EKOS.Graph] START NODE NOT FOUND"
    }

    $visited = @{}
    $result  = @()

    if ($Mode -eq "DFS") {

        function DFS($node) {
            if ($visited[$node]) { return }

            $visited[$node] = $true
            $result += $node

            $neighbors = $state.edges |
                Where-Object { $_.from -eq $node } |
                Select-Object -ExpandProperty to

            foreach ($n in $neighbors) {
                DFS $n
            }
        }

        DFS $StartNode
    }

    if ($Mode -eq "BFS") {

        $queue = New-Object System.Collections.Queue
        $queue.Enqueue($StartNode)

        while ($queue.Count -gt 0) {

            $node = $queue.Dequeue()

            if ($visited[$node]) { continue }

            $visited[$node] = $true
            $result += $node

            $neighbors = $state.edges |
                Where-Object { $_.from -eq $node } |
                Select-Object -ExpandProperty to

            foreach ($n in $neighbors) {
                if (-not $visited[$n]) {
                    $queue.Enqueue($n)
                }
            }
        }
    }

    return $result
}