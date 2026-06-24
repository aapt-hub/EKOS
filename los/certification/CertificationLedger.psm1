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

Set-StrictMode -Version Latest

function Write-LOSCertificationLedger {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RootPath,

        [Parameter(Mandatory)]
        [object] $Entry

    )

    begin {
        $ledgerDir = Join-Path $RootPath "los\\certification-data\\ledger"
        $ledgerFile = Join-Path $ledgerDir "certification-ledger.jsonl"

        if (-not (Test-Path -LiteralPath $ledgerDir)) {
            New-Item -ItemType Directory -Path $ledgerDir | Out-Null
        }

        $null
    }

    process {
        if ($null -eq $Entry) {
            throw "Ledger entry is null"
        }

        if (-not ($Entry.PSObject.Properties.Name -contains "CertificationId")) {
            throw "Ledger entry missing CertificationId"
        }
        if (-not ($Entry.PSObject.Properties.Name -contains "TimestampUtc")) {
            throw "Ledger entry missing TimestampUtc"
        }
        if (-not ($Entry.PSObject.Properties.Name -contains "EvidenceHash")) {
            throw "Ledger entry missing EvidenceHash"
        }
        if (-not ($Entry.PSObject.Properties.Name -contains "CertificationStatus")) {
            throw "Ledger entry missing CertificationStatus"
        }

        $json = $Entry | ConvertTo-Json -Depth 8 -Compress
        Add-Content -LiteralPath $ledgerFile -Value $json

        [PSCustomObject][ordered]@{
            Success = $true
            LedgerFile = $ledgerFile
            Entry = $Entry
        }
    }
}

function Read-LOSCertificationLedger {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RootPath
    )

    $ledgerFile = Join-Path $RootPath "los\\certification-data\\ledger\\certification-ledger.jsonl"
    if (-not (Test-Path -LiteralPath $ledgerFile)) {
        return @()
    }

    $lines = Get-Content -LiteralPath $ledgerFile
    $out = @()
    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $out += ($line | ConvertFrom-Json)
    }

    return $out
}

Export-ModuleMember -Function Write-LOSCertificationLedger, Read-LOSCertificationLedger

