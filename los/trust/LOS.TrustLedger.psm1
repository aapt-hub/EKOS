Set-StrictMode -Version Latest

function Write-LOSTrustLedger {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RootPath,

        [Parameter(Mandatory)]
        [object] $Entry
    )

    if ($null -eq $Entry) {
        throw "Trust ledger entry is null"
    }

    foreach ($requiredProperty in @("TimestampUtc", "Decision", "TrustStatus", "TrustEvidenceHash")) {
        if ($Entry.PSObject.Properties.Name -notcontains $requiredProperty) {
            throw "Trust ledger entry missing $requiredProperty"
        }
    }

    $ledgerDir = Join-Path $RootPath "los\trust-data"
    $ledgerFile = Join-Path $ledgerDir "trust-ledger.json"
    if (-not (Test-Path -LiteralPath $ledgerDir)) {
        New-Item -ItemType Directory -Path $ledgerDir | Out-Null
    }

    $json = $Entry | ConvertTo-Json -Depth 10 -Compress
    Add-Content -LiteralPath $ledgerFile -Value $json

    return [PSCustomObject][ordered]@{
        Success    = $true
        LedgerFile = $ledgerFile
        Entry      = $Entry
    }
}

function Read-LOSTrustLedger {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RootPath
    )

    $ledgerFile = Join-Path $RootPath "los\trust-data\trust-ledger.json"
    if (-not (Test-Path -LiteralPath $ledgerFile)) {
        return @()
    }

    $rows = @()
    foreach ($line in @(Get-Content -LiteralPath $ledgerFile)) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        $rows += ($line | ConvertFrom-Json)
    }

    return $rows
}

Export-ModuleMember -Function Write-LOSTrustLedger, Read-LOSTrustLedger
