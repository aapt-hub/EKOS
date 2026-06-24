function Test-EKOSDuplicateEdge {
    param([hashtable]$Graph)

    $seen = @{}

    foreach ($edge in $Graph.Edges) {
        $key = "$($edge.From)->$($edge.To)"

        if ($seen[$key]) {
            throw "Duplicate edge detected: $key"
        }

        $seen[$key] = $true
    }

    return $true
}