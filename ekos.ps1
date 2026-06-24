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

<#
EKOS CLI v3 FIXED
#>

param(
    [string]$command,
    [string]$arg
)

$root = "C:\Repos\EKOS"
$aiRouter = "$root\graph\ai\ai-router.ps1"
$aiState  = "$root\graph\ai\ai-state.json"

# -----------------------------
# LOAD AI ENGINE
# -----------------------------
if (Test-Path $aiRouter) {
    . $aiRouter
}

# -----------------------------
# FUNCTIONS
# -----------------------------
function Show-Help {
    Write-Host ""
    Write-Host "EKOS CLI v3 Commands:" -ForegroundColor Cyan
    Write-Host "  .\ekos.ps1 ai <text>"
    Write-Host "  .\ekos.ps1 status"
    Write-Host "  .\ekos.ps1 graph status"
    Write-Host ""
}

function Get-Status {
    Write-Host "EKOS CLI v3 - OK" -ForegroundColor Green
    Write-Host "Root : $root"

    if (Test-Path $aiState) {
        $state = Get-Content $aiState | ConvertFrom-Json
        Write-Host "AI Usage: $($state.used_today)/$($state.daily_budget)"
    }
}

function Get-GraphStatus {
    Write-Host "Graph system status: OK (placeholder)"
}

function Run-AI($text) {
    if (Get-Command Invoke-EKOSAI -ErrorAction SilentlyContinue) {
        Invoke-EKOSAI $text
    } else {
        Write-Host "AI engine not loaded" -ForegroundColor Red
    }
}

# -----------------------------
# ROUTER (must come AFTER param)
# -----------------------------
switch ($command) {

    "ai" {
        Run-AI $arg
    }

    "status" {
        Get-Status
    }

    "graph" {
        if ($arg -eq "status") {
            Get-GraphStatus
        }
    }

    default {
        Show-Help
    }
}