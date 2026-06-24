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
LOS Runtime Trust Recovery.

.DESCRIPTION
Implements LOS-TRUST-004 Runtime Trust Recovery as an evidence-based restoration workflow. Recovery approval authorizes revalidation only; it does not restore trust or activate a subject by itself.

Author: Abner Pauneto
Project: EKOS
Subsystem: LOS Trust Authority Layer
Capability: LOS-TRUST-004
Roadmap Milestone: M2.11
Status: Complete
#>
Set-StrictMode -Version Latest

$script:RecoverableStates = @("Quarantined", "Denied")
$script:FinalStates = @("Active", "RecoveryRejected")

function Get-LOSRecoveryTimestampUtc {
    [CmdletBinding()]
    param(
        [string] $TimestampUtc = ""
    )

    if ([string]::IsNullOrWhiteSpace($TimestampUtc)) {
        return (Get-Date).ToUniversalTime().ToString("o")
    }

    return $TimestampUtc
}

function Get-LOSRecoveryLedgerPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RootPath
    )

    $ledgerDir = Join-Path $RootPath "los\trust\ledger"
    if (-not (Test-Path -LiteralPath $ledgerDir)) {
        New-Item -ItemType Directory -Path $ledgerDir -Force | Out-Null
    }

    return Join-Path $ledgerDir "recovery-ledger.jsonl"
}

function ConvertTo-LOSRecoveryCanonicalObject {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object] $InputObject
    )

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [string] -or $InputObject -is [int] -or $InputObject -is [long] -or $InputObject -is [double] -or $InputObject -is [decimal] -or $InputObject -is [bool]) {
        return $InputObject
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $ordered = [ordered]@{}
        foreach ($key in @($InputObject.Keys | Sort-Object)) {
            $ordered[[string] $key] = ConvertTo-LOSRecoveryCanonicalObject -InputObject $InputObject[$key]
        }
        return [PSCustomObject] $ordered
    }

    if ($InputObject -is [System.Collections.IEnumerable] -and -not ($InputObject -is [string])) {
        $items = @()
        foreach ($item in $InputObject) {
            $items += ConvertTo-LOSRecoveryCanonicalObject -InputObject $item
        }
        return $items
    }

    $properties = @($InputObject.PSObject.Properties.Name | Sort-Object)
    if ($properties.Count -gt 0) {
        $ordered = [ordered]@{}
        foreach ($name in $properties) {
            $ordered[$name] = ConvertTo-LOSRecoveryCanonicalObject -InputObject $InputObject.$name
        }
        return [PSCustomObject] $ordered
    }

    return [string] $InputObject
}

function ConvertTo-LOSRecoveryCanonicalJson {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object] $InputObject
    )

    $canonical = ConvertTo-LOSRecoveryCanonicalObject -InputObject $InputObject
    if ($null -eq $canonical) {
        return "null"
    }

    return ($canonical | ConvertTo-Json -Depth 30 -Compress)
}

function Get-LOSRecoverySha256 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Value
    )

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
        $hash = $sha.ComputeHash($bytes)
        return ([System.BitConverter]::ToString($hash) -replace "-", "").ToLowerInvariant()
    }
    finally {
        if ($sha -is [System.IDisposable]) {
            $sha.Dispose()
        }
    }
}

function Get-LOSRecoveryEvidenceHash {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object] $Evidence
    )

    return Get-LOSRecoverySha256 -Value (ConvertTo-LOSRecoveryCanonicalJson -InputObject $Evidence)
}

function New-LOSRecoveryRequestId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $TrustId,

        [Parameter(Mandatory)]
        [string] $Reason,

        [Parameter(Mandatory)]
        [string] $EvidenceHash,

        [Parameter(Mandatory)]
        [string] $RequestedBy
    )

    return Get-LOSRecoverySha256 -Value (ConvertTo-LOSRecoveryCanonicalJson -InputObject ([PSCustomObject][ordered]@{
        EvidenceHash = $EvidenceHash
        Reason       = $Reason
        RequestedBy  = $RequestedBy
        TrustId      = $TrustId
    }))
}

function Get-LOSRecoveryPropertyValue {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object] $InputObject,

        [Parameter(Mandatory)]
        [string] $Name
    )

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        if ($InputObject.Contains($Name)) {
            return $InputObject[$Name]
        }
        return $null
    }

    if ($InputObject.PSObject.Properties.Name -contains $Name) {
        return $InputObject.$Name
    }

    return $null
}

function Test-LOSRecoveryEvidence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $Evidence
    )

    if ($null -eq $Evidence) {
        throw "MissingEvidence"
    }

    $expected = [ordered]@{
        CertificationStatus = "Passed"
        AttestationStatus   = "Valid"
        PolicyStatus        = "Compliant"
        IntegrityStatus     = "Passed"
    }

    foreach ($name in $expected.Keys) {
        $value = Get-LOSRecoveryPropertyValue -InputObject $Evidence -Name $name
        if ($null -eq $value -or [string] $value -ne $expected[$name]) {
            throw ("Invalid" + $name)
        }
    }

    return $true
}

function Read-LOSRecoveryLedger {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RootPath
    )

    $ledgerFile = Join-Path $RootPath "los\trust\ledger\recovery-ledger.jsonl"
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

function Get-LOSRecoveryLatestEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Events,

        [Parameter(Mandatory)]
        [string] $RecoveryRequestId
    )

    $history = @($Events | Where-Object { $_.RecoveryRequestId -eq $RecoveryRequestId })
    if ($history.Count -eq 0) {
        return $null
    }

    return $history[-1]
}

function New-LOSRecoveryDecisionHash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RecoveryRequestId,

        [Parameter(Mandatory)]
        [string] $TrustId,

        [Parameter(Mandatory)]
        [string] $PreviousState,

        [Parameter(Mandatory)]
        [string] $CurrentState,

        [Parameter(Mandatory)]
        [string] $Action,

        [Parameter(Mandatory)]
        [string] $EvidenceHash,

        [string] $Actor = "",

        [string] $Reason = ""
    )

    return Get-LOSRecoverySha256 -Value (ConvertTo-LOSRecoveryCanonicalJson -InputObject ([PSCustomObject][ordered]@{
        Action            = $Action
        Actor             = $Actor
        CurrentState      = $CurrentState
        EvidenceHash      = $EvidenceHash
        PreviousState     = $PreviousState
        Reason            = $Reason
        RecoveryRequestId = $RecoveryRequestId
        TrustId           = $TrustId
    }))
}

function Add-LOSRecoveryLedgerEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RootPath,

        [Parameter(Mandatory)]
        [string] $RecoveryRequestId,

        [Parameter(Mandatory)]
        [string] $TrustId,

        [Parameter(Mandatory)]
        [string] $PreviousState,

        [Parameter(Mandatory)]
        [string] $CurrentState,

        [Parameter(Mandatory)]
        [string] $Action,

        [Parameter(Mandatory)]
        [string] $Reason,

        [Parameter(Mandatory)]
        [string] $EvidenceHash,

        [Parameter(Mandatory)]
        [string] $RequestedBy,

        [string] $ApprovedBy = "",

        [string] $DeniedBy = "",

        [AllowNull()]
        [object] $Evidence = $null,

        [string] $TimestampUtc = ""
    )

    $timestamp = Get-LOSRecoveryTimestampUtc -TimestampUtc $TimestampUtc
    $actor = $RequestedBy
    if (-not [string]::IsNullOrWhiteSpace($ApprovedBy)) {
        $actor = $ApprovedBy
    }
    elseif (-not [string]::IsNullOrWhiteSpace($DeniedBy)) {
        $actor = $DeniedBy
    }

    $event = [PSCustomObject][ordered]@{
        RecoveryRequestId = $RecoveryRequestId
        TrustId           = $TrustId
        PreviousState     = $PreviousState
        CurrentState      = $CurrentState
        Action            = $Action
        Reason            = $Reason
        EvidenceHash      = $EvidenceHash
        DecisionHash      = New-LOSRecoveryDecisionHash -RecoveryRequestId $RecoveryRequestId -TrustId $TrustId -PreviousState $PreviousState -CurrentState $CurrentState -Action $Action -EvidenceHash $EvidenceHash -Actor $actor -Reason $Reason
        RequestedBy       = $RequestedBy
        ApprovedBy        = $ApprovedBy
        DeniedBy          = $DeniedBy
        TimestampUtc      = $timestamp
        Evidence          = ConvertTo-LOSRecoveryCanonicalObject -InputObject $Evidence
    }

    $ledgerFile = Get-LOSRecoveryLedgerPath -RootPath $RootPath
    Add-Content -LiteralPath $ledgerFile -Value ($event | ConvertTo-Json -Depth 30 -Compress)
    return $event
}

function Get-LOSRecoveryActiveRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Events,

        [Parameter(Mandatory)]
        [string] $TrustId,

        [string] $EvidenceHash = ""
    )

    $requestIds = @($Events | Where-Object { $_.TrustId -eq $TrustId } | Select-Object -ExpandProperty RecoveryRequestId -Unique)
    foreach ($requestId in $requestIds) {
        $latest = Get-LOSRecoveryLatestEvent -Events $Events -RecoveryRequestId $requestId
        if ($null -eq $latest) {
            continue
        }

        $isFinal = $latest.CurrentState -in $script:FinalStates
        $sameEvidence = [string]::IsNullOrWhiteSpace($EvidenceHash) -or $latest.EvidenceHash -eq $EvidenceHash
        if (-not $isFinal -and $sameEvidence) {
            return $latest
        }
    }

    return $null
}

function Request-LOSTrustRecovery {
    [CmdletBinding()]
    param(
        [string] $RootPath = ".",

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $TrustId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Reason,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object] $Evidence,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $RequestedBy,

        [ValidateSet("Active", "Quarantined", "Denied", "Revoked")]
        [string] $CurrentState = "Quarantined",

        [string] $TimestampUtc = ""
    )

    if ($CurrentState -eq "Revoked") {
        throw "RevokedTrustCannotRecoverDirectly"
    }

    if ($CurrentState -notin $script:RecoverableStates) {
        throw "RecoveryRequiresQuarantinedOrDeniedState"
    }

    Test-LOSRecoveryEvidence -Evidence $Evidence | Out-Null

    $evidenceHash = Get-LOSRecoveryEvidenceHash -Evidence $Evidence
    $events = @(Read-LOSRecoveryLedger -RootPath $RootPath)
    $active = Get-LOSRecoveryActiveRequest -Events $events -TrustId $TrustId
    if ($null -ne $active) {
        throw "DuplicateActiveRecoveryRequest"
    }

    $replay = Get-LOSRecoveryActiveRequest -Events $events -TrustId $TrustId -EvidenceHash $evidenceHash
    if ($null -ne $replay) {
        throw "DuplicateRecoveryReplay"
    }

    $requestId = New-LOSRecoveryRequestId -TrustId $TrustId -Reason $Reason -EvidenceHash $evidenceHash -RequestedBy $RequestedBy
    $existing = Get-LOSRecoveryLatestEvent -Events $events -RecoveryRequestId $requestId
    if ($null -ne $existing -and $existing.CurrentState -notin $script:FinalStates) {
        throw "DuplicateActiveRecoveryRequest"
    }

    return Add-LOSRecoveryLedgerEvent -RootPath $RootPath -RecoveryRequestId $requestId -TrustId $TrustId -PreviousState $CurrentState -CurrentState "RecoveryRequested" -Action "RecoveryRequested" -Reason $Reason -EvidenceHash $evidenceHash -RequestedBy $RequestedBy -Evidence $Evidence -TimestampUtc $TimestampUtc
}

function Approve-LOSTrustRecovery {
    [CmdletBinding()]
    param(
        [string] $RootPath = ".",

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $RecoveryRequestId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ApprovedBy,

        [string] $TimestampUtc = ""
    )

    $events = @(Read-LOSRecoveryLedger -RootPath $RootPath)
    $latest = Get-LOSRecoveryLatestEvent -Events $events -RecoveryRequestId $RecoveryRequestId
    if ($null -eq $latest) {
        throw "RecoveryRequestNotFound"
    }
    if ($latest.CurrentState -ne "RecoveryRequested") {
        throw "RecoveryRequestIsNotPending"
    }

    Add-LOSRecoveryLedgerEvent -RootPath $RootPath -RecoveryRequestId $RecoveryRequestId -TrustId $latest.TrustId -PreviousState "RecoveryRequested" -CurrentState "RecoveryApproved" -Action "RecoveryApproved" -Reason $latest.Reason -EvidenceHash $latest.EvidenceHash -RequestedBy $latest.RequestedBy -ApprovedBy $ApprovedBy -Evidence $latest.Evidence -TimestampUtc $TimestampUtc | Out-Null
    return Add-LOSRecoveryLedgerEvent -RootPath $RootPath -RecoveryRequestId $RecoveryRequestId -TrustId $latest.TrustId -PreviousState "RecoveryApproved" -CurrentState "RevalidationRequired" -Action "RevalidationRequired" -Reason "Recovery approval authorizes revalidation." -EvidenceHash $latest.EvidenceHash -RequestedBy $latest.RequestedBy -ApprovedBy $ApprovedBy -Evidence $latest.Evidence -TimestampUtc $TimestampUtc
}

function Deny-LOSTrustRecovery {
    [CmdletBinding()]
    param(
        [string] $RootPath = ".",

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $RecoveryRequestId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $DeniedBy,

        [string] $Reason = "Recovery denied.",

        [string] $TimestampUtc = ""
    )

    $events = @(Read-LOSRecoveryLedger -RootPath $RootPath)
    $latest = Get-LOSRecoveryLatestEvent -Events $events -RecoveryRequestId $RecoveryRequestId
    if ($null -eq $latest) {
        throw "RecoveryRequestNotFound"
    }
    if ($latest.CurrentState -ne "RecoveryRequested") {
        throw "RecoveryRequestIsNotPending"
    }

    return Add-LOSRecoveryLedgerEvent -RootPath $RootPath -RecoveryRequestId $RecoveryRequestId -TrustId $latest.TrustId -PreviousState "RecoveryRequested" -CurrentState "RecoveryRejected" -Action "RecoveryRejected" -Reason $Reason -EvidenceHash $latest.EvidenceHash -RequestedBy $latest.RequestedBy -DeniedBy $DeniedBy -Evidence $latest.Evidence -TimestampUtc $TimestampUtc
}

function Resolve-LOSTrustRecovery {
    [CmdletBinding()]
    param(
        [string] $RootPath = ".",

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $RecoveryRequestId,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object] $Evidence,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ReviewedBy,

        [string] $TimestampUtc = ""
    )

    Test-LOSRecoveryEvidence -Evidence $Evidence | Out-Null

    $events = @(Read-LOSRecoveryLedger -RootPath $RootPath)
    $latest = Get-LOSRecoveryLatestEvent -Events $events -RecoveryRequestId $RecoveryRequestId
    if ($null -eq $latest) {
        throw "RecoveryRequestNotFound"
    }
    if ($latest.CurrentState -notin @("RecoveryApproved", "RevalidationRequired")) {
        throw "RecoveryRequiresApprovedOrRevalidationState"
    }

    $evidenceHash = Get-LOSRecoveryEvidenceHash -Evidence $Evidence
    $state = [string] $latest.CurrentState
    if ($state -eq "RecoveryApproved") {
        Add-LOSRecoveryLedgerEvent -RootPath $RootPath -RecoveryRequestId $RecoveryRequestId -TrustId $latest.TrustId -PreviousState "RecoveryApproved" -CurrentState "RevalidationRequired" -Action "RevalidationRequired" -Reason "Recovery approval authorizes revalidation." -EvidenceHash $evidenceHash -RequestedBy $latest.RequestedBy -ApprovedBy $latest.ApprovedBy -Evidence $Evidence -TimestampUtc $TimestampUtc | Out-Null
        $state = "RevalidationRequired"
    }

    $stages = @(
        "CertificationValidated",
        "AttestationValidated",
        "PolicyValidated",
        "TrustAuthorityReviewed",
        "Restored",
        "Active"
    )

    $last = $null
    foreach ($stage in $stages) {
        $reason = $stage
        if ($stage -eq "Active") {
            $reason = "Subject restored to Active after certification, attestation, policy, and trust authority validation."
        }

        $last = Add-LOSRecoveryLedgerEvent -RootPath $RootPath -RecoveryRequestId $RecoveryRequestId -TrustId $latest.TrustId -PreviousState $state -CurrentState $stage -Action $stage -Reason $reason -EvidenceHash $evidenceHash -RequestedBy $latest.RequestedBy -ApprovedBy $ReviewedBy -Evidence $Evidence -TimestampUtc $TimestampUtc
        $state = $stage
    }

    return $last
}

function Get-LOSTrustRecovery {
    [CmdletBinding(DefaultParameterSetName = "All")]
    param(
        [string] $RootPath = ".",

        [Parameter(ParameterSetName = "ByRequestId")]
        [string] $RecoveryRequestId,

        [Parameter(ParameterSetName = "ByTrustId")]
        [string] $TrustId
    )

    $events = @(Read-LOSRecoveryLedger -RootPath $RootPath)
    if ($PSCmdlet.ParameterSetName -eq "ByRequestId") {
        return @($events | Where-Object { $_.RecoveryRequestId -eq $RecoveryRequestId })
    }
    if ($PSCmdlet.ParameterSetName -eq "ByTrustId") {
        return @($events | Where-Object { $_.TrustId -eq $TrustId })
    }

    return $events
}

function Get-LOSTrustRecoveryState {
    [CmdletBinding()]
    param(
        [string] $RootPath = "."
    )

    $events = @(Read-LOSRecoveryLedger -RootPath $RootPath)
    $requests = @()
    foreach ($requestId in @($events | Select-Object -ExpandProperty RecoveryRequestId -Unique)) {
        $history = @($events | Where-Object { $_.RecoveryRequestId -eq $requestId })
        if ($history.Count -eq 0) {
            continue
        }
        $latest = $history[-1]
        $requests += [PSCustomObject][ordered]@{
            RecoveryRequestId = $requestId
            TrustId           = $latest.TrustId
            CurrentState      = $latest.CurrentState
            EvidenceHash      = $latest.EvidenceHash
            EventCount        = $history.Count
            History           = $history
        }
    }

    return [PSCustomObject][ordered]@{
        Requests = $requests
        Events   = $events
    }
}

function Clear-LOSTrustRecoveryState {
    [CmdletBinding()]
    param(
        [string] $RootPath = "."
    )

    $ledgerFile = Join-Path $RootPath "los\trust\ledger\recovery-ledger.jsonl"
    if (Test-Path -LiteralPath $ledgerFile) {
        Remove-Item -LiteralPath $ledgerFile -Force
    }

    return [PSCustomObject][ordered]@{
        Success    = $true
        LedgerFile = $ledgerFile
    }
}

Export-ModuleMember -Function Request-LOSTrustRecovery, Approve-LOSTrustRecovery, Deny-LOSTrustRecovery, Resolve-LOSTrustRecovery, Get-LOSTrustRecovery, Get-LOSTrustRecoveryState, Clear-LOSTrustRecoveryState
