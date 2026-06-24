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
LOS Policy Decision Engine.

.DESCRIPTION
Evaluates applicable policy actions and produces a deterministic policy decision object.

Fail-closed when policy evaluation is missing or ambiguous.
#>
Set-StrictMode -Version Latest

$script:PolicyDecisionState = [ordered]@{
    Decisions = @()
}

function Clear-LOSPolicyDecisionState {
    [CmdletBinding()]
    param()

    $script:PolicyDecisionState = [ordered]@{ Decisions = @() }
    return [PSCustomObject][ordered]@{ Success = $true; Cleared = $true }
}

function Get-LOSPolicyDecisionState {
    [CmdletBinding()]
    param()

    return $script:PolicyDecisionState
}

function Get-LOSCanonicalJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $InputObject
    )

    # Canonical deterministic JSON for evidence hashing.
    function ConvertTo-CanonicalObject {
        param([AllowNull()] [object] $obj)

        if ($null -eq $obj) { return $null }
        $t = $obj.GetType()

        if ($obj -is [string] -or $obj -is [int] -or $obj -is [long] -or $obj -is [double] -or $obj -is [decimal] -or $obj -is [bool]) {
            return $obj
        }

        if ($obj -is [System.Collections.IDictionary]) {
            $ordered = [ordered]@{}
            foreach ($k in @($obj.Keys | Sort-Object {[string]$_})) {
                $ordered[[string]$k] = ConvertTo-CanonicalObject -obj $obj[$k]
            }
            return [PSCustomObject]$ordered
        }

        if ($obj -is [System.Collections.IEnumerable] -and -not ($obj -is [string])) {
            $items = @()
            foreach ($item in $obj) {
                $items += (ConvertTo-CanonicalObject -obj $item)
            }
            return $items
        }

        $props = @($obj.PSObject.Properties.Name | Sort-Object)
        if ($props.Count -gt 0) {
            $ordered = [ordered]@{}
            foreach ($p in $props) {
                $ordered[$p] = ConvertTo-CanonicalObject -obj $obj.$p
            }
            return [PSCustomObject]$ordered
        }

        return [string]$obj
    }

    $canonical = ConvertTo-CanonicalObject -obj $InputObject
    return ($canonical | ConvertTo-Json -Depth 40 -Compress)
}

function Get-LOSPolicyEvidenceHash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $Evidence
    )

    $json = Get-LOSCanonicalJson -InputObject $Evidence
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
        $hash = $sha.ComputeHash($bytes)
        return ([System.BitConverter]::ToString($hash) -replace "-", "").ToLowerInvariant()
    }
    finally {
        if ($sha -is [System.IDisposable]) { $sha.Dispose() }
    }
}

function New-LOSPolicyDecision {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $DecisionId,

        [Parameter(Mandatory)]
        [string] $PolicyId,

        [Parameter(Mandatory)]
        [string] $SubjectId,

        [Parameter(Mandatory)]
        [ValidateSet("Allow","Deny","Quarantine","Revoke","Escalate","Recover","NoMatch")]
        [string] $Result,

        [Parameter(Mandatory)]
        [object[]] $Actions,

        [Parameter(Mandatory)]
        [ValidateSet("Info","Warning","Critical")]
        [string] $Severity,

        [Parameter(Mandatory)]
        [string] $TimestampUtc,

        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $Evidence
    )

    $allowedSeverity = @("Info","Warning","Critical")
    if ($Severity -notin $allowedSeverity) {
        throw "InvalidSeverity"
    }

    $evidenceHash = Get-LOSPolicyEvidenceHash -Evidence $Evidence

    $decision = [PSCustomObject][ordered]@{
        DecisionId   = $DecisionId
        PolicyId     = $PolicyId
        SubjectId    = $SubjectId
        Result       = $Result
        Actions      = @($Actions)
        Severity     = $Severity
        TimestampUtc = $TimestampUtc
        EvidenceHash = $evidenceHash
        Evidence     = $Evidence
    }

    # Store deterministic in-memory state for tests.
    $script:PolicyDecisionState.Decisions += $decision
    return $decision
}

Export-ModuleMember -Function New-LOSPolicyDecision, Get-LOSPolicyDecisionState, Clear-LOSPolicyDecisionState

