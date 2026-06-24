Set-StrictMode -Version Latest

function Invoke-LOSCertificationHarness {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RootPath,

        [Parameter(Mandatory)]
        [object] $BrokerResult,

        [Parameter(Mandatory)]
        [object] $Evidence,

        [Parameter(Mandatory)]
        [object] $ReferenceEvidence
    )

    $failureModule = Join-Path $PSScriptRoot "CertificationFailureTaxonomy.psm1"
    $evidenceModule = Join-Path $PSScriptRoot "CertificationEvidence.psm1"
    $ledgerModule = Join-Path $PSScriptRoot "CertificationLedger.psm1"
    $reportModule = Join-Path $PSScriptRoot "CertificationReport.psm1"
    $parityModule = Join-Path $PSScriptRoot "CertificationParity.psm1"

    Import-Module $failureModule -Force -Global
    Import-Module $ledgerModule -Force -Global
    Import-Module $reportModule -Force -Global
    Import-Module $parityModule -Force -Global

    # Evidence is passed by value; attempt to import to ensure helper exports.
    try {
        Import-Module $evidenceModule -Force -Global
    }
    catch {
        # ignore
    }

    if ($null -eq $BrokerResult) {
        return [PSCustomObject][ordered]@{
            Success = $false
            Decision = "DENY"
            Reason = "GovernanceFailure"
        }
    }

    if (-not ($BrokerResult.PSObject.Properties.Name -contains "Decision") -or $BrokerResult.Decision -ne "ALLOW") {
        return [PSCustomObject][ordered]@{
            Success = $false
            Decision = "DENY"
            Reason = "GovernanceFailure"
        }
    }

    $parity = Test-LOSCertificationParity -LeftEvidence $Evidence -RightEvidence $ReferenceEvidence
    if ($null -eq $parity -or $parity.ParityStatus -ne "Passed") {
        $failure = Get-LOSCertificationFailure -FailureCategory "ParityFailure" -Details "Parity check failed"
        return [PSCustomObject][ordered]@{
            Success = $false
            Decision = "DENY"
            Failure = $failure
            Parity = $parity
        }
    }

    # EvidenceHash: SHA256(canonicalJson(evidence))
    # Canonical serializer is under repoRoot (not necessarily the temp RootPath).
    $serializerPath = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..\\.." )).Path "graph\\tools\\EKOS.CanonicalSerializer.psm1"
    Import-Module $serializerPath -Force -Global

    $evidenceCanonical = ConvertTo-EkosCanonicalJson -InputObject $Evidence
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($evidenceCanonical)
    $hashBytes = ([System.Security.Cryptography.SHA256]::Create()).ComputeHash($bytes)
    $evidenceHash = ([System.BitConverter]::ToString($hashBytes) -replace '-', '').ToLowerInvariant()

    $ledgerEntry = [PSCustomObject][ordered]@{
        CertificationId = $Evidence.CertificationId
        TimestampUtc = $Evidence.TimestampUtc
        EvidenceHash = $evidenceHash
        CertificationStatus = "PASS"
    }

    $ledgerWrite = $null
    try {
        $ledgerWrite = Write-LOSCertificationLedger -RootPath $RootPath -Entry $ledgerEntry
    }
    catch {
        $failure = Get-LOSCertificationFailure -FailureCategory "LedgerFailure" -Details $_.Exception.Message
        return [PSCustomObject][ordered]@{
            Success = $false
            Decision = "DENY"
            Failure = $failure
            LedgerWriteError = $_.Exception.Message
        }
    }

    $governanceStatus = [PSCustomObject][ordered]@{
        Decision = "ALLOW"
    }

    $failureOk = Get-LOSCertificationFailure -FailureCategory "UnknownFailure" -Details ""

    $json = New-LOSCertificationReport `
        -Evidence $Evidence `
        -GovernanceStatus $governanceStatus `
        -ParityResult $parity `
        -EvidenceHash $evidenceHash `
        -CertificationStatus "PASS" `
        -TimestampUtc $Evidence.TimestampUtc `
        -Failure $failureOk

    $reportsDir = Join-Path $RootPath "los\\certification-data\\reports"
    if (-not (Test-Path -LiteralPath $reportsDir)) {
        New-Item -ItemType Directory -Path $reportsDir | Out-Null
    }
    $reportPath = Join-Path $reportsDir ("certification-report-" + $Evidence.CertificationId + ".json")
    Set-Content -LiteralPath $reportPath -Value $json -Encoding UTF8

    return [PSCustomObject][ordered]@{
        Success = $true
        Decision = "ALLOW"
        Evidence = $Evidence
        Parity = $parity
        LedgerWrite = $ledgerWrite
        ReportPath = $reportPath
        CertificationStatus = "PASS"
    }
}

Export-ModuleMember -Function Invoke-LOSCertificationHarness

