<#
.SYNOPSIS
EKOS Identity Stabilizer v1 - deterministic node identity system

.DESCRIPTION
Creates stable identities for files and directories in EKOS Graph v3.
Solves drift, duplicate nodes, and unstable graph reconstruction.

AUTHOR: EKOS Graph System
VERSION: 1.0.0
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ==============================
# HASH CORE
# ==============================

function Get-EkosHash {
    param (
        [Parameter(Mandatory)]
        [string]$InputString
    )

    $sha = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($InputString)
    $hash = $sha.ComputeHash($bytes)

    return ([BitConverter]::ToString($hash) -replace "-", "").ToLower()
}

# ==============================
# FILE IDENTITY
# ==============================

function Get-EkosFileIdentity {
    param (
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    if (!(Test-Path $FilePath)) {
        throw "File not found: $FilePath"
    }

    $content = Get-Content $FilePath -Raw -ErrorAction Stop

    # Normalize line endings
    $normalized = $content -replace "`r`n", "`n"

    $signature = "$FilePath|$normalized"
    return Get-EkosHash $signature
}

# ==============================
# DIRECTORY IDENTITY (CRITICAL FIX)
# ==============================

function Get-EkosDirectoryIdentity {
    param (
        [Parameter(Mandatory)]
        [string]$DirectoryPath
    )

    if (!(Test-Path $DirectoryPath)) {
        throw "Directory not found: $DirectoryPath"
    }

    $items = Get-ChildItem -Path $DirectoryPath -Recurse -Force |
        Sort-Object FullName

    $manifest = foreach ($item in $items) {

        # FIX: handle dotfiles + empty basenames safely
        $name = if ([string]::IsNullOrWhiteSpace($item.Name)) {
            $item.FullName
        } else {
            $item.Name
        }

        $type = if ($item.PSIsContainer) { "DIR" } else { "FILE" }

        "$type|$name|$item.Length"
    }

    $manifestString = ($manifest -join "`n")

    # Include directory path for uniqueness
    $signature = "$DirectoryPath`n$manifestString"

    return Get-EkosHash $signature
}

# ==============================
# NODE NORMALIZER
# ==============================

function New-EkosNodeIdentity {
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (Test-Path $Path -PathType Container) {
        return @{
            Type = "Directory"
            Path = $Path
            Identity = Get-EkosDirectoryIdentity $Path
        }
    }
    else {
        return @{
            Type = "File"
            Path = $Path
            Identity = Get-EkosFileIdentity $Path
        }
    }
}

# ==============================
# GRAPH STABILIZER ENGINE
# ==============================

function Invoke-EkosIdentityStabilizer {
    param (
        [Parameter(Mandatory)]
        [string]$RootPath,

        [switch]$DetectDuplicates
    )

    Write-Host "🧬 EKOS Identity Stabilizer starting..." -ForegroundColor Cyan

    $nodes = @{}
    $duplicates = @{}

    $allItems = Get-ChildItem -Path $RootPath -Recurse -Force

    foreach ($item in $allItems) {

        $node = New-EkosNodeIdentity -Path $item.FullName
        $id = $node.Identity

        if ($nodes.ContainsKey($id)) {
            $duplicates[$id] += ,$item.FullName
        }
        else {
            $nodes[$id] = $node
        }
    }

    Write-Host "✔ Nodes stabilized: $($nodes.Count)" -ForegroundColor Green

    if ($DetectDuplicates) {
        Write-Host "⚠ Duplicate identity clusters: $($duplicates.Count)" -ForegroundColor Yellow

        return @{
            Nodes = $nodes
            Duplicates = $duplicates
        }
    }

    return $nodes
}

# ==============================
# EXPORT SAFE GRAPH SNAPSHOT
# ==============================

function Export-EkosIdentityGraph {
    param (
        [Parameter(Mandatory)]
        [string]$RootPath,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    $graph = Invoke-EkosIdentityStabilizer -RootPath $RootPath -DetectDuplicates

    $output = @{
        Timestamp = Get-Date -Format "o"
        Root = $RootPath
        NodeCount = $graph.Nodes.Count
        DuplicateClusters = $graph.Duplicates.Count
        Nodes = $graph.Nodes
    }

    $json = $output | ConvertTo-Json -Depth 10
    Set-Content -Path $OutputPath -Value $json -Encoding UTF8

    Write-Host "✔ Graph exported → $OutputPath" -ForegroundColor Green
}