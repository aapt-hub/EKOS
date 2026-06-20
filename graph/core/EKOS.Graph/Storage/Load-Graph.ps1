function Load-Graph {
    $path = "$PSScriptRoot\..\Data\graph.json"

    if (Test-Path $path) {
        $Global:EKOS_Graph = Get-Content $path | ConvertFrom-Json -Depth 10
    }
}