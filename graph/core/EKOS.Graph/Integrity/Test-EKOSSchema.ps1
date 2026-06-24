function Test-EKOSSchema {
    param([hashtable]$Graph)

    foreach ($node in $Graph.Nodes.Values) {
        if (-not $node.Id) {
            throw "Schema violation: Node missing Id"
        }

        if (-not $node.Type) {
            throw "Schema violation: Node missing Type"
        }
    }

    return $true
}