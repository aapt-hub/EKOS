function Save-Graph {
    $Global:EKOS_Graph | ConvertTo-Json -Depth 10 |
        Set-Content "$PSScriptRoot\..\Data\graph.json"
}