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
.SYNOPSIS
LOS Trust Decision.

.DESCRIPTION
Evaluates trust evidence and fail-closed runtime trust decision conditions.

Author: Abner Pauneto
Project: EKOS
Subsystem: LOS
Phase: M2.8
Status: Complete
#>
Set-StrictMode -Version Latest

function New-LOSTrustDenyDecision {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Reason
    )

    return [PSCustomObject][ordered]@{
        Success     = $false
        Decision    = "DENY"
        TrustStatus = "UNTRUSTED"
        Reason      = $Reason
    }
}

function New-LOSTrustDecision {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $TrustEvidence,

        [string[]] $RequiredCapabilities = @(),

        [string[]] $AllowedRuntimeHashes = @()
    )

    if ($null -eq $TrustEvidence) {
        return New-LOSTrustDenyDecision -Reason "TrustEvidenceMissing"
    }

    $properties = @($TrustEvidence.PSObject.Properties.Name)
    foreach ($requiredProperty in @("RuntimeId", "RuntimeVersion", "RuntimeHash", "CertificationStatus", "EvidenceHash", "TrustEvidenceHash")) {
        if ($properties -notcontains $requiredProperty) {
            return New-LOSTrustDenyDecision -Reason "TrustEvidenceInvalid"
        }
    }

    if ($TrustEvidence.CertificationStatus -ne "PASS") {
        return New-LOSTrustDenyDecision -Reason "CertificationNotTrusted"
    }

    if ([string]::IsNullOrWhiteSpace([string] $TrustEvidence.RuntimeHash)) {
        return New-LOSTrustDenyDecision -Reason "RuntimeHashMissing"
    }

    if (@($AllowedRuntimeHashes).Count -gt 0 -and @($AllowedRuntimeHashes) -notcontains $TrustEvidence.RuntimeHash) {
        return New-LOSTrustDenyDecision -Reason "RuntimeHashNotTrusted"
    }

    $capabilities = @()
    if ($properties -contains "Capabilities") {
        $capabilities = @($TrustEvidence.Capabilities)
    }

    foreach ($requiredCapability in @($RequiredCapabilities)) {
        if ($capabilities -notcontains $requiredCapability) {
            return New-LOSTrustDenyDecision -Reason "CapabilityNotTrusted"
        }
    }

    return [PSCustomObject][ordered]@{
        Success           = $true
        Decision          = "ALLOW"
        TrustStatus       = "TRUSTED"
        Reason            = "TrustedRuntime"
        RuntimeId         = $TrustEvidence.RuntimeId
        RuntimeVersion    = $TrustEvidence.RuntimeVersion
        RuntimeHash       = $TrustEvidence.RuntimeHash
        TrustEvidenceHash = $TrustEvidence.TrustEvidenceHash
    }
}

Export-ModuleMember -Function New-LOSTrustDecision
