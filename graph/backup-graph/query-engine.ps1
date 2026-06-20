# EKOS Sprint 1 - Query Engine
# Provides exact ID matching, neighbor lookup, and text search.

$script:EKOSGraphRoot = $PSScriptRoot
$script:EKOSNodesPath = Join-Path $script:EKOSGraphRoot "nodes.json"
$script:EKOSEdgesPath = Join-Path $script:EKOSGraphRoot "edges.json"

function Get-EKOSNodes {
    if (-not (Test-Path $script:EKOSNodesPath)) {
        return @()
    }

    $content = Get-Content -Path $script:EKOSNodesPath -Raw

    if ([string]::IsNullOrWhiteSpace($content)) {
        return @()
    }

    return @(ConvertFrom-Json -InputObject $content)
}

function Get-EKOSEdges {
    if (-not (Test-Path $script:EKOSEdgesPath)) {
        return @()
    }

    $content = Get-Content -Path $script:EKOSEdgesPath -Raw

    if ([string]::IsNullOrWhiteSpace($content)) {
        return @()
    }

    return @(ConvertFrom-Json -InputObject $content)
}

function Query-EKOS {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateSet("match", "neighbors", "search")]
        [string]$Mode,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$Value
    )

    $nodes = Get-EKOSNodes
    $edges = Get-EKOSEdges

    switch ($Mode.ToLowerInvariant()) {
        "match" {
            return $nodes | Where-Object {
                $_.id -ieq $Value
            }
        }

        "neighbors" {
            return $edges | Where-Object {
                $_.from -ieq $Value -or $_.to -ieq $Value
            }
        }

        "search" {
            $nodeResults = $nodes | Where-Object {
                $_.id -like "*$Value*" -or
                $_.title -like "*$Value*" -or
                $_.type -like "*$Value*"
            }

            $edgeResults = $edges | Where-Object {
                $_.from -like "*$Value*" -or
                $_.to -like "*$Value*" -or
                $_.type -like "*$Value*"
            }

            return [PSCustomObject]@{
                nodes = @($nodeResults)
                edges = @($edgeResults)
            }
        }
    }
}
