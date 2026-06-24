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

function Add-LOSTrustRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RootPath,

        [Parameter(Mandatory)]
        [object] $Entry
    )

    Write-LOSTrustLedger -RootPath $RootPath -Entry $Entry
}

function Get-LOSTrustLedger {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RootPath
    )

    Read-LOSTrustLedger -RootPath $RootPath
}

function Get-LOSTrustRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RootPath,

        [Parameter(Mandatory)]
        [string] $TrustId
    )

    foreach ($record in @(Read-LOSTrustLedger -RootPath $RootPath)) {
        $properties = @($record.PSObject.Properties.Name)
        if ($properties -contains "TrustId" -and $record.TrustId -eq $TrustId) {
            return $record
        }
        if ($properties -contains "TrustEvidenceId" -and $record.TrustEvidenceId -eq $TrustId) {
            return $record
        }
        if ($properties -contains "TrustEvidenceHash" -and $record.TrustEvidenceHash -eq $TrustId) {
            return $record
        }
    }

    return $null
}

function Test-LOSTrustLedgerIntegrity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RootPath
    )

    try {
        $records = @(Read-LOSTrustLedger -RootPath $RootPath)
        $index = 0
        foreach ($record in $records) {
            $index++
            foreach ($requiredProperty in @("TimestampUtc", "Decision", "TrustStatus", "TrustEvidenceHash")) {
                if ($record.PSObject.Properties.Name -notcontains $requiredProperty) {
                    return [PSCustomObject][ordered]@{
                        Success = $false
                        Valid   = $false
                        Reason  = "Missing$requiredProperty"
                        Index   = $index
                    }
                }
            }

            if ($record.Decision -notin @("ALLOW", "DENY")) {
                return [PSCustomObject][ordered]@{
                    Success = $false
                    Valid   = $false
                    Reason  = "InvalidDecision"
                    Index   = $index
                }
            }

            if ($record.TrustStatus -notin @("TRUSTED", "UNTRUSTED")) {
                return [PSCustomObject][ordered]@{
                    Success = $false
                    Valid   = $false
                    Reason  = "InvalidTrustStatus"
                    Index   = $index
                }
            }
        }

        return [PSCustomObject][ordered]@{
            Success = $true
            Valid   = $true
            Reason  = "LedgerIntegrityValid"
            Count   = $records.Count
        }
    }
    catch {
        return [PSCustomObject][ordered]@{
            Success = $false
            Valid   = $false
            Reason  = "LedgerIntegrityError"
            Error   = $_.Exception.Message
        }
    }
}

Export-ModuleMember -Function Write-LOSTrustLedger, Read-LOSTrustLedger, Add-LOSTrustRecord, Get-LOSTrustLedger, Get-LOSTrustRecord, Test-LOSTrustLedgerIntegrity
