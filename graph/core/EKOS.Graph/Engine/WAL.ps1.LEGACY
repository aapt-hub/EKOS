# =========================================================
# EKOS.Graph v3 — WRITE AHEAD LOG (WAL)
# =========================================================

$Global:EKOS_WAL_PATH = "$PSScriptRoot\..\Data\wal.log"

# ---------------------------------------------------------
# Initialize WAL storage
# ---------------------------------------------------------
function Initialize-WAL {

    $dataPath = "$PSScriptRoot\..\Data"

    if (!(Test-Path $dataPath)) {
        New-Item -ItemType Directory -Path $dataPath | Out-Null
    }

    if (!(Test-Path $Global:EKOS_WAL_PATH)) {
        New-Item -ItemType File -Path $Global:EKOS_WAL_PATH | Out-Null
    }

    Write-Host "[EKOS.Graph] WAL READY"
}

# ---------------------------------------------------------
# Write operation to WAL (append-only log)
# ---------------------------------------------------------
function Write-WAL {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Action,

        [Parameter(Mandatory = $true)]
        [object]$Payload
    )

    $entry = @{
        time    = (Get-Date)
        action  = $Action
        payload = $Payload
    }

    # Force single-line, safe JSON (NO multiline corruption)
    $json = $entry | ConvertTo-Json -Depth 20 -Compress

    Add-Content -Path $Global:EKOS_WAL_PATH -Value $json
}

# ---------------------------------------------------------
# Replay WAL to rebuild graph state
# ---------------------------------------------------------
function Replay-WAL {

    # Ensure dependencies exist
    Initialize-GraphState
    Initialize-WAL

    if (!(Test-Path $Global:EKOS_WAL_PATH)) {
        Write-Host "[EKOS.Graph] WAL EMPTY — NOTHING TO REPLAY"
        return
    }

    $lines = Get-Content $Global:EKOS_WAL_PATH

    foreach ($line in $lines) {

        # Skip empty/corrupt lines safely
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        try {
            $entry = $line | ConvertFrom-Json
        }
        catch {
            Write-Warning "[EKOS.Graph] CORRUPT WAL ENTRY SKIPPED"
            continue
        }

        switch ($entry.action) {

            "AddNode" {
                Add-Node `
                    -Name $entry.payload.name `
                    -Type $entry.payload.type `
                    -Replay
            }

            "AddEdge" {
                Add-Edge `
                    -From $entry.payload.from `
                    -To $entry.payload.to `
                    -Relation $entry.payload.relation `
                    -Replay
            }

            default {
                Write-Warning "[EKOS.Graph] UNKNOWN WAL ACTION: $($entry.action)"
            }
        }
    }

    Write-Host "[EKOS.Graph] WAL REPLAY COMPLETE"
}