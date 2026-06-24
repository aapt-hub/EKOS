<#
AUTHOR:
Abner Pauneto

COPYRIGHT:
Copyright (c) 2026 Abner Pauneto

LICENSE:
Proprietary – All Rights Reserved

PROJECT:
EKOS

STATUS:
Private Development
#>

# ============================================================
# EKOS v3.3 INDEXER (STABLE + DEBUG ENHANCED)
# ============================================================
# FIXED ISSUES:
# - ArrayList corruption / += crash eliminated
# - Safe JSON hydration
# - Execution pipeline guaranteed
# - Embedding failures now visible (not silent)
# - Edge creation validated
# - Safe graph persistence
# ============================================================

Write-Host "EKOS v3.3 Indexer starting..." -ForegroundColor Cyan

# ============================================================
# CONFIGURATION
# ============================================================

$graphPath = "C:\Repos\EKOS\graph"
$nodesFile = Join-Path $graphPath "nodes.json"
$edgesFile = Join-Path $graphPath "edges.json"

# ============================================================
# SAFE DATA STRUCTURES (CRITICAL FIX)
# ============================================================

$script:nodes = New-Object System.Collections.ArrayList
$script:edges = New-Object System.Collections.ArrayList

$script:embeddingCache = @{}
$script:vectorIndex = @{}
$script:MAX_EDGES_PER_NODE = 5

# ============================================================
# LOAD EXISTING GRAPH SAFELY
# ============================================================

function Load-Graph {

    Write-Host "Loading existing graph..." -ForegroundColor Yellow

    if (Test-Path $nodesFile) {
        try {
            $loadedNodes = Get-Content $nodesFile -Raw | ConvertFrom-Json

            if ($loadedNodes) {
                foreach ($n in $loadedNodes) {
                    [void]$script:nodes.Add($n)
                }
            }
        }
        catch {
            Write-Host "⚠️ Failed to load nodes.json, starting fresh" -ForegroundColor Red
        }
    }

    if (Test-Path $edgesFile) {
        try {
            $loadedEdges = Get-Content $edgesFile -Raw | ConvertFrom-Json

            if ($loadedEdges) {
                foreach ($e in $loadedEdges) {
                    [void]$script:edges.Add($e)
                }
            }
        }
        catch {
            Write-Host "⚠️ Failed to load edges.json, starting fresh" -ForegroundColor Red
        }
    }

    Write-Host "Nodes loaded: $($script:nodes.Count)" -ForegroundColor Green
    Write-Host "Edges loaded: $($script:edges.Count)" -ForegroundColor Green
}

# ============================================================
# EMBEDDING ENGINE (WITH FULL DEBUG)
# ============================================================

function Get-Embedding {
    param($text)

    $apiKey = $env:OPENAI_API_KEY

    if (-not $apiKey) {
        throw "OPENAI_API_KEY is missing"
    }

    $uri = "https://api.openai.com/v1/embeddings"

    $body = @{
        model = "text-embedding-3-small"
        input = $text
    } | ConvertTo-Json -Depth 10

    try {
        $response = Invoke-RestMethod -Uri $uri `
            -Method Post `
            -Headers @{
                "Authorization" = "Bearer $apiKey"
                "Content-Type" = "application/json"
            } `
            -Body $body

        return $response.data[0].embedding
    }
    catch {
        Write-Host "❌ EMBEDDING FAILED for: $text" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red

        if ($_.ErrorDetails) {
            Write-Host $_.ErrorDetails.Message -ForegroundColor Yellow
        }

        return $null
    }
}

function Get-EmbeddingCached {
    param($text)

    if ($script:embeddingCache.ContainsKey($text)) {
        return $script:embeddingCache[$text]
    }

    $embedding = Get-Embedding $text

    if ($embedding) {
        $script:embeddingCache[$text] = $embedding
    }

    return $embedding
}

# ============================================================
# NODE POLICY
# ============================================================

function Should-Embed {
    param($id)
    return ($id -match "PAT-|ADR-|RUN-|ARC-")
}

# ============================================================
# NODE CREATION
# ============================================================

function New-KnowledgeNode {
    param($id, $type, $label)

    $node = @{
        id = $id
        type = $type
        label = $label
        embedding = $null
        metadata = @{
            frequency = 1
            confidence = 0.5
        }
        createdAt = (Get-Date).ToString("o")
    }

    if (Should-Embed $id) {
        $embedding = Get-EmbeddingCached $label

        if ($embedding) {
            $node.embedding = $embedding
            $node.metadata.confidence = 0.8
            $script:vectorIndex[$id] = $embedding
        }
    }

    return $node
}

# ============================================================
# VECTOR SIMILARITY
# ============================================================

function Cosine-Similarity {
    param($a, $b)

    if (-not $a -or -not $b) { return 0 }

    $dot = 0
    $magA = 0
    $magB = 0

    for ($i = 0; $i -lt $a.Count; $i++) {
        $dot += $a[$i] * $b[$i]
        $magA += $a[$i] * $a[$i]
        $magB += $b[$i] * $b[$i]
    }

    if ($magA -eq 0 -or $magB -eq 0) { return 0 }

    return $dot / ([math]::Sqrt($magA) * [math]::Sqrt($magB))
}

# ============================================================
# EDGE CREATION
# ============================================================

function Add-Embedding-Edge {
    param($fromNode, $toNode)

    if (-not $fromNode.embedding -or -not $toNode.embedding) {
        return
    }

    $cosine = Cosine-Similarity $fromNode.embedding $toNode.embedding

    $score =
        ($cosine * 0.7) +
        ([math]::Min(
            $fromNode.metadata.confidence,
            $toNode.metadata.confidence
        ) * 0.3)

    if ($score -lt 0.72) { return }

    $edgeId = "$($fromNode.id)->$($toNode.id):embedding"

    foreach ($e in $script:edges) {
        if ($e.id -eq $edgeId) { return }
    }

    $count = 0
    foreach ($e in $script:edges) {
        if ($e.from -eq $fromNode.id) { $count++ }
    }

    if ($count -ge $script:MAX_EDGES_PER_NODE) { return }

    [void]$script:edges.Add(@{
        id = $edgeId
        from = $fromNode.id
        to = $toNode.id
        type = "semantic_embedding"
        weight = $score
        createdAt = (Get-Date).ToString("o")
    })
}

# ============================================================
# TEST DATA SOURCE (REPLACE LATER WITH FILE SCANNER)
# ============================================================

function Get-SourceDocuments {
    return @(
        @{ id="PAT-001"; type="pattern"; label="GitOps deployment pattern" },
        @{ id="ADR-001"; type="architecture"; label="Microservices decision record" },
        @{ id="RUN-001"; type="runbook"; label="Kubernetes rollback procedure" }
    )
}

# ============================================================
# NODE PIPELINE
# ============================================================

function Add-Or-IndexNode {
    param($id, $type, $label)

    $node = New-KnowledgeNode $id $type $label

    [void]$script:nodes.Add($node)

    foreach ($existing in $script:nodes) {

        if ($existing.id -eq $node.id) { continue }
        if (-not $existing.embedding -or -not $node.embedding) { continue }

        Add-Embedding-Edge $node $existing
    }
}

# ============================================================
# SAFE SAVE
# ============================================================

function Save-Graph {

    if (-not $script:nodes -or $script:nodes.Count -eq 0) {
        Write-Host "❌ Abort: No nodes generated" -ForegroundColor Red
        return
    }

    $script:nodes | ConvertTo-Json -Depth 10 | Set-Content $nodesFile
    $script:edges | ConvertTo-Json -Depth 10 | Set-Content $edgesFile

    Write-Host "Graph saved successfully" -ForegroundColor Green
    Write-Host "Nodes: $($script:nodes.Count)" -ForegroundColor Green
    Write-Host "Edges: $($script:edges.Count)" -ForegroundColor Green
}

# ============================================================
# EXECUTION PIPELINE (CRITICAL SECTION)
# ============================================================

Load-Graph

Write-Host "Running EKOS indexing pipeline..." -ForegroundColor Yellow

$docs = Get-SourceDocuments

foreach ($doc in $docs) {
    Add-Or-IndexNode $doc.id $doc.type $doc.label
}

Save-Graph

Write-Host "EKOS indexing complete." -ForegroundColor Cyan