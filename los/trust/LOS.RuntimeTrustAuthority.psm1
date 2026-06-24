Set-StrictMode -Version Latest

function Invoke-LOSRuntimeTrustAuthority {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RootPath,

        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $GovernanceResult,

        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $CertificationResult,

        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $TrustEvidence,

        [string[]] $RequiredCapabilities = @(),

        [string[]] $AllowedRuntimeHashes = @(),

        [string] $TimestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    )

    Import-Module (Join-Path $PSScriptRoot "LOS.TrustDecision.psm1") -Force -Global
    Import-Module (Join-Path $PSScriptRoot "LOS.TrustLedger.psm1") -Force -Global
    Import-Module (Join-Path $PSScriptRoot "LOS.TrustReport.psm1") -Force -Global

    if ($null -eq $GovernanceResult -or -not ($GovernanceResult.PSObject.Properties.Name -contains "Decision") -or $GovernanceResult.Decision -ne "ALLOW") {
        $decision = [PSCustomObject][ordered]@{
            Success     = $false
            Decision    = "DENY"
            TrustStatus = "UNTRUSTED"
            Reason      = "GovernanceNotAllowed"
        }
    }
    elseif ($null -eq $CertificationResult -or -not ($CertificationResult.PSObject.Properties.Name -contains "CertificationStatus") -or $CertificationResult.CertificationStatus -ne "PASS") {
        $decision = [PSCustomObject][ordered]@{
            Success     = $false
            Decision    = "DENY"
            TrustStatus = "UNTRUSTED"
            Reason      = "CertificationNotTrusted"
        }
    }
    else {
        $decision = New-LOSTrustDecision -TrustEvidence $TrustEvidence -RequiredCapabilities $RequiredCapabilities -AllowedRuntimeHashes $AllowedRuntimeHashes
    }

    $trustEvidenceHash = ""
    if ($null -ne $TrustEvidence -and $TrustEvidence.PSObject.Properties.Name -contains "TrustEvidenceHash") {
        $trustEvidenceHash = $TrustEvidence.TrustEvidenceHash
    }

    $ledgerEntry = [PSCustomObject][ordered]@{
        TimestampUtc       = $TimestampUtc
        Decision           = $decision.Decision
        TrustStatus        = $decision.TrustStatus
        Reason             = $decision.Reason
        TrustEvidenceHash  = $trustEvidenceHash
    }

    $ledgerWrite = Write-LOSTrustLedger -RootPath $RootPath -Entry $ledgerEntry
    $reportJson = New-LOSTrustReport -TrustDecision $decision -TrustEvidence $TrustEvidence -GeneratedUtc $TimestampUtc

    $reportDir = Join-Path $RootPath "los\trust-data\reports"
    if (-not (Test-Path -LiteralPath $reportDir)) {
        New-Item -ItemType Directory -Path $reportDir | Out-Null
    }

    $reportPath = Join-Path $reportDir ("trust-report-" + ($TimestampUtc -replace "[:\.]", "-") + ".json")
    Set-Content -LiteralPath $reportPath -Value $reportJson -Encoding UTF8

    return [PSCustomObject][ordered]@{
        Success      = $decision.Success
        Decision     = $decision.Decision
        TrustStatus  = $decision.TrustStatus
        Reason       = $decision.Reason
        TrustEvidence = $TrustEvidence
        LedgerWrite  = $ledgerWrite
        ReportPath   = $reportPath
    }
}

Export-ModuleMember -Function Invoke-LOSRuntimeTrustAuthority
