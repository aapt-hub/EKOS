# EKOS Sprint 1 - Edge and Node Generator
# Converts Markdown documents into deterministic nodes.json and edges.json files.

$graphRoot = $PSScriptRoot
$repositoryRoot = Split-Path $graphRoot -Parent
$nodesPath = Join-Path $graphRoot "nodes.json"
$edgesPath = Join-Path $graphRoot "edges.json"

. (Join-Path $graphRoot "entity-extractor.ps1")
. (Join-Path $graphRoot "relationship-engine.ps1")

$documentLocations = @(
    @{ Path = "patterns";        Type = "pattern" },
    @{ Path = "adrs";            Type = "adr" },
    @{ Path = "runbooks";        Type = "runbook" },
    @{ Path = "architectures";   Type = "architecture" },
    @{ Path = "lessons-learned"; Type = "lesson" }
)

function Get-EKOSDocumentId {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File,

        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    $fileMatch = [regex]::Match(
        $File.BaseName,
        "(?i)\b[A-Z][A-Z0-9]*-\d+\b"
    )

    if ($fileMatch.Success) {
        return $fileMatch.Value.ToUpperInvariant()
    }

    $headerMatch = [regex]::Match(
        $Text,
        "(?im)^\s*#\s+.*?\b([A-Z][A-Z0-9]*-\d+)\b"
    )

    if ($headerMatch.Success) {
        return $headerMatch.Groups[1].Value.ToUpperInvariant()
    }

    return $File.BaseName
}

function Get-EKOSDocumentTitle {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File,

        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [string]$DocumentId
    )

    $headerMatch = [regex]::Match($Text, "(?im)^\s*#\s+(.+?)\s*$")

    if ($headerMatch.Success) {
        $title = $headerMatch.Groups[1].Value.Trim()
        $title = [regex]::Replace(
            $title,
            "^(?i)" + [regex]::Escape($DocumentId) + "\s*[:\-]\s*",
            ""
        )

        if (-not [string]::IsNullOrWhiteSpace($title)) {
            return $title
        }
    }

    $fallbackTitle = $File.BaseName
    $fallbackTitle = [regex]::Replace(
        $fallbackTitle,
        "^(?i)" + [regex]::Escape($DocumentId) + "[-_\s]*",
        ""
    )
    $fallbackTitle = $fallbackTitle -replace "[-_]+", " "

    if ([string]::IsNullOrWhiteSpace($fallbackTitle)) {
        return $DocumentId
    }

    return $fallbackTitle.Trim()
}

$nodes = @()
$allEdges = @()

foreach ($location in $documentLocations) {
    $sourcePath = Join-Path $repositoryRoot $location.Path

    if (-not (Test-Path $sourcePath)) {
        continue
    }

    $files = Get-ChildItem -Path $sourcePath -Filter "*.md" -File |
        Sort-Object FullName

    foreach ($file in $files) {
        $text = Get-Content -Path $file.FullName -Raw
        $documentId = Get-EKOSDocumentId -File $file -Text $text
        $title = Get-EKOSDocumentTitle `
            -File $file `
            -Text $text `
            -DocumentId $documentId

        $nodes += [PSCustomObject]@{
            id    = $documentId
            title = $title
            type  = $location.Type
        }

        $allEdges += Get-EKOSEntityEdges `
            -DocumentId $documentId `
            -Text $text

        $allEdges += Get-EKOSRelationshipEdges `
            -DocumentId $documentId `
            -Text $text
    }
}

# Remove duplicate nodes using their IDs.
$nodeKeys = @{}
$uniqueNodes = @()

foreach ($node in $nodes) {
    $key = $node.id.ToLowerInvariant()

    if (-not $nodeKeys.ContainsKey($key)) {
        $nodeKeys[$key] = $true
        $uniqueNodes += $node
    }
}

# Remove duplicate edges using from, to, and type.
$edgeKeys = @{}
$uniqueEdges = @()

foreach ($edge in $allEdges) {
    $key = (
        $edge.from.ToLowerInvariant() + "|" +
        $edge.to.ToLowerInvariant() + "|" +
        $edge.type.ToLowerInvariant()
    )

    if (-not $edgeKeys.ContainsKey($key)) {
        $edgeKeys[$key] = $true
        $uniqueEdges += $edge
    }
}

$uniqueNodes = @(
    $uniqueNodes |
        Sort-Object type, id
)

$uniqueEdges = @(
    $uniqueEdges |
        Sort-Object from, to, type
)

ConvertTo-Json -InputObject $uniqueNodes -Depth 5 |
    Set-Content -Path $nodesPath -Encoding UTF8

ConvertTo-Json -InputObject $uniqueEdges -Depth 5 |
    Set-Content -Path $edgesPath -Encoding UTF8

Write-Host "EKOS Sprint 1 graph generated."
Write-Host "Nodes: $($uniqueNodes.Count)"
Write-Host "Edges: $($uniqueEdges.Count)"
