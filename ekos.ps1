
# ==============================
# EKOS CLI v3 - STABLE EDITION
# ==============================

$EKOS_ROOT = "C:\repos\ekos"
$INDEX_FILE = "$EKOS_ROOT\metadata\pattern-index.json"

# ------------------------------
# Load Pattern Index
# ------------------------------
function Get-EkosIndex {
    if (-not (Test-Path $INDEX_FILE)) {
        Write-Host "Index not found: $INDEX_FILE" -ForegroundColor Red
        return $null
    }

    try {
        return Get-Content $INDEX_FILE -Raw | ConvertFrom-Json
    }
    catch {
        Write-Host "ERROR: Invalid JSON in pattern-index.json" -ForegroundColor Red
        return $null
    }
}

# ------------------------------
# PATTERNS LIST
# ------------------------------
function ekos-patterns-list {
    $index = Get-EkosIndex
    if (-not $index) { return }

    foreach ($p in $index.patterns) {
        Write-Host "[$($p.id)] $($p.name)"
    }
}

# ------------------------------
# PATTERNS SEARCH
# ------------------------------
function ekos-patterns-search {
    param([string]$query)

    $index = Get-EkosIndex
    if (-not $index) { return }

    $results = $index.patterns | Where-Object {
        $_.id -like "*$query*" -or
        $_.name -like "*$query*" -or
        ($_.tags -join " ") -like "*$query*"
    }

    if (-not $results) {
        Write-Host "No results for: $query" -ForegroundColor Yellow
        return
    }

    foreach ($p in $results) {
        Write-Host ""
        Write-Host "[$($p.id)] $($p.name)" -ForegroundColor Cyan
        Write-Host "File: $($p.file)"
        Write-Host "Tags: $($p.tags -join ', ')"
    }
}

# ------------------------------
# ADRs (placeholder)
# ------------------------------
function ekos-adrs-list {
    Write-Host "ADRs: not implemented yet"
}

# ------------------------------
# RUNBOOKS (placeholder)
# ------------------------------
function ekos-runbooks-list {
    Write-Host "Runbooks: not implemented yet"
}

# ------------------------------
# STATUS
# ------------------------------
function ekos-status {
    Write-Host "EKOS CLI v3 - OK"
    Write-Host "Root : $EKOS_ROOT"
    Write-Host "Index: $INDEX_FILE"
}

# ------------------------------
# COMMAND ROUTER (CORE)
# ------------------------------
function ekos {
    param(
        [string]$Command,
        [string]$SubCommand,
        [string]$Argument
    )

    switch ($Command) {

        "patterns" {
            switch ($SubCommand) {
                "list"   { ekos-patterns-list }
                "search" { ekos-patterns-search $Argument }
                default  {
                    Write-Host "Usage:"
                    Write-Host "  ekos patterns list"
                    Write-Host "  ekos patterns search <query>"
                }
            }
        }

        "adrs" {
            switch ($SubCommand) {
                "list" { ekos-adrs-list }
                default { Write-Host "Usage: ekos adrs list" }
            }
        }

        "runbooks" {
            switch ($SubCommand) {
                "list" { ekos-runbooks-list }
                default { Write-Host "Usage: ekos runbooks list" }
            }
        }

        "status" {
            ekos-status
        }

        default {
            Write-Host ""
            Write-Host "EKOS CLI Commands:"
            Write-Host "  ekos status"
            Write-Host "  ekos patterns list"
            Write-Host "  ekos patterns search <query>"
            Write-Host "  ekos adrs list"
            Write-Host "  ekos runbooks list"
            Write-Host ""
        }
    }
}

# ------------------------------
# SAFE ENTRY POINT (NO RECURSION)
# ------------------------------
# This allows: .\ekos.ps1 status
if ($args.Count -gt 0) {
    ekos $args[0] $args[1] $args[2]
}