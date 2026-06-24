$ErrorActionPreference = "Stop"

$NodesPath = ".\nodes.json"
$EdgesPath = ".\edges.json"
$OutputPath = ".\graph-state.json"

function Throw-EKOS($code, $msg) {
    throw "[$code] $msg"
}

function LoadJson($path, $label) {
    if (!(Test-Path $path)) {
        Throw-EKOS "FILE_MISSING" "$label missing"
    }
    return Get-Content $path -Raw | ConvertFrom-Json
}

function GetNodes($raw) {
    if ($raw -is [array]) { return $raw }
    if ($raw.nodes) { return $raw.nodes }
    return @()
}

function GetEdges($raw) {
    if ($raw -is [array]) { return $raw }
    if ($raw.edges) { return $raw.edges }
    return @()
}

Write-Host "EKOS Indexer CLEAN START"

$nodesRaw = LoadJson $NodesPath "nodes.json"
$edgesRaw = LoadJson $EdgesPath "edges.json"

$nodes = GetNodes $nodesRaw
$edges = GetEdges $edgesRaw

$cleanNodes = @()

foreach ($n in $nodes) {
    if ($n -and $n.id) {
        $cleanNodes += $n
    }
}

$index = @{}
foreach ($n in $cleanNodes) {
    $index[$n.id] = $true
}

$cleanEdges = @()

foreach ($e in $edges) {
    if ($e -and $e.from -and $e.to) {
        if ($index[$e.from] -and $index[$e.to]) {
            $cleanEdges += $e
        }
    }
}

@{
    nodes = $cleanNodes
    edges = $cleanEdges
} | ConvertTo-Json -Depth 10 | Set-Content $OutputPath

Write-Host "EKOS INDEX COMPLETE"
