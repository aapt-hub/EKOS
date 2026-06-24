<#
.SYNOPSIS
LOS Trust Report.

.DESCRIPTION
Emits structured JSON trust reports from trust decisions and trust evidence.

Author: Abner Pauneto
Project: EKOS
Subsystem: LOS
Phase: M2.8
Status: Complete
#>
Set-StrictMode -Version Latest

function New-LOSTrustReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $TrustDecision,

        [Parameter(Mandatory)]
        [object] $TrustEvidence,

        [string] $GeneratedUtc = (Get-Date).ToUniversalTime().ToString("o")
    )

    $report = [PSCustomObject][ordered]@{
        GeneratedUtc       = $GeneratedUtc
        Decision           = if ($null -ne $TrustDecision -and $TrustDecision.PSObject.Properties.Name -contains "Decision") { $TrustDecision.Decision } else { "DENY" }
        TrustStatus        = if ($null -ne $TrustDecision -and $TrustDecision.PSObject.Properties.Name -contains "TrustStatus") { $TrustDecision.TrustStatus } else { "UNTRUSTED" }
        Reason             = if ($null -ne $TrustDecision -and $TrustDecision.PSObject.Properties.Name -contains "Reason") { $TrustDecision.Reason } else { "TrustDecisionMissing" }
        RuntimeId          = if ($null -ne $TrustEvidence -and $TrustEvidence.PSObject.Properties.Name -contains "RuntimeId") { $TrustEvidence.RuntimeId } else { "" }
        RuntimeVersion     = if ($null -ne $TrustEvidence -and $TrustEvidence.PSObject.Properties.Name -contains "RuntimeVersion") { $TrustEvidence.RuntimeVersion } else { "" }
        TrustEvidenceHash  = if ($null -ne $TrustEvidence -and $TrustEvidence.PSObject.Properties.Name -contains "TrustEvidenceHash") { $TrustEvidence.TrustEvidenceHash } else { "" }
    }

    return ($report | ConvertTo-Json -Depth 10)
}

Export-ModuleMember -Function New-LOSTrustReport
