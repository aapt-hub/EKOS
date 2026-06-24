Set-StrictMode -Version Latest

function Get-LOSTrustEnforcementStatePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RootPath
    )

    $stateDir = Join-Path $RootPath "los\trust\data"
    if (-not (Test-Path -LiteralPath $stateDir)) {
        New-Item -ItemType Directory -Path $stateDir | Out-Null
    }

    return Join-Path $stateDir "runtime-trust-enforcement.json"
}

function Get-LOSTrustEnforcementSha256 {
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

function New-LOSTrustEnforcementId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $SubjectId,

        [Parameter(Mandatory)]
        [string] $Action,

        [Parameter(Mandatory)]
        [string] $Reason,

        [Parameter(Mandatory)]
        [string] $TimestampUtc,

        [string] $EvidenceHash = ""
    )

    return Get-LOSTrustEnforcementSha256 -Value ($SubjectId + "|" + $Action + "|" + $Reason + "|" + $TimestampUtc + "|" + $EvidenceHash)
}

function Read-LOSTrustEnforcementRecords {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RootPath
    )

    $statePath = Get-LOSTrustEnforcementStatePath -RootPath $RootPath
    if (-not (Test-Path -LiteralPath $statePath)) {
        return @()
    }

    $content = Get-Content -LiteralPath $statePath -Raw
    if ([string]::IsNullOrWhiteSpace($content)) {
        return @()
    }

    $parsed = $content | ConvertFrom-Json
    if ($null -eq $parsed) {
        return @()
    }

    if ($parsed.PSObject.Properties.Name -contains "Records") {
        return @($parsed.Records)
    }

    return @($parsed)
}

function Write-LOSTrustEnforcementRecords {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RootPath,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Records
    )

    $statePath = Get-LOSTrustEnforcementStatePath -RootPath $RootPath
    $sortedRecords = @($Records | Sort-Object SubjectId, TimestampUtc)
    $state = [PSCustomObject][ordered]@{
        Records = $sortedRecords
    }
    Set-Content -LiteralPath $statePath -Value ($state | ConvertTo-Json -Depth 20) -Encoding UTF8
    return $statePath
}

function Add-LOSTrustEnforcementRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RootPath,

        [Parameter(Mandatory)]
        [string] $SubjectId,

        [Parameter(Mandatory)]
        [ValidateSet("Quarantine", "Deny", "Revoke")]
        [string] $Action,

        [Parameter(Mandatory)]
        [string] $Reason,

        [Parameter(Mandatory)]
        [ValidateSet("Info", "Warning", "Critical")]
        [string] $Severity,

        [string] $Source = "",

        [string] $EvidenceHash = "",

        [string] $TimestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    )

    if ([string]::IsNullOrWhiteSpace($Source)) {
        $Source = "LOS.RuntimeTrustEnforcement"
    }

    $record = [PSCustomObject][ordered]@{
        SubjectId     = $SubjectId
        Action        = $Action
        Reason        = $Reason
        Severity      = $Severity
        TimestampUtc  = $TimestampUtc
        Source        = $Source
        EvidenceHash  = $EvidenceHash
        EnforcementId = New-LOSTrustEnforcementId -SubjectId $SubjectId -Action $Action -Reason $Reason -TimestampUtc $TimestampUtc -EvidenceHash $EvidenceHash
    }

    $records = @(Read-LOSTrustEnforcementRecords -RootPath $RootPath)
    $records += $record
    Write-LOSTrustEnforcementRecords -RootPath $RootPath -Records $records | Out-Null

    return $record
}

function Quarantine-LOSTrustSubject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RootPath,

        [Parameter(Mandatory)]
        [string] $SubjectId,

        [Parameter(Mandatory)]
        [string] $Reason,

        [ValidateSet("Info", "Warning", "Critical")]
        [string] $Severity = "Warning",

        [string] $Source = "Quarantine-LOSTrustSubject",

        [string] $EvidenceHash = "",

        [string] $TimestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    )

    Add-LOSTrustEnforcementRecord -RootPath $RootPath -SubjectId $SubjectId -Action "Quarantine" -Reason $Reason -Severity $Severity -Source $Source -EvidenceHash $EvidenceHash -TimestampUtc $TimestampUtc
}

function Deny-LOSTrustSubject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RootPath,

        [Parameter(Mandatory)]
        [string] $SubjectId,

        [Parameter(Mandatory)]
        [string] $Reason,

        [ValidateSet("Info", "Warning", "Critical")]
        [string] $Severity = "Critical",

        [string] $Source = "Deny-LOSTrustSubject",

        [string] $EvidenceHash = "",

        [string] $TimestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    )

    Add-LOSTrustEnforcementRecord -RootPath $RootPath -SubjectId $SubjectId -Action "Deny" -Reason $Reason -Severity $Severity -Source $Source -EvidenceHash $EvidenceHash -TimestampUtc $TimestampUtc
}

function Revoke-LOSTrustSubject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RootPath,

        [Parameter(Mandatory)]
        [string] $SubjectId,

        [Parameter(Mandatory)]
        [string] $Reason,

        [ValidateSet("Info", "Warning", "Critical")]
        [string] $Severity = "Critical",

        [string] $Source = "Revoke-LOSTrustSubject",

        [string] $EvidenceHash = "",

        [string] $TimestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    )

    Add-LOSTrustEnforcementRecord -RootPath $RootPath -SubjectId $SubjectId -Action "Revoke" -Reason $Reason -Severity $Severity -Source $Source -EvidenceHash $EvidenceHash -TimestampUtc $TimestampUtc
}

function Get-LOSTrustEnforcementState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RootPath,

        [string] $SubjectId = ""
    )

    $records = @(Read-LOSTrustEnforcementRecords -RootPath $RootPath)
    if (-not [string]::IsNullOrWhiteSpace($SubjectId)) {
        $records = @($records | Where-Object { $_.SubjectId -eq $SubjectId })
    }

    return [PSCustomObject][ordered]@{
        Records = @($records | Sort-Object SubjectId, TimestampUtc)
    }
}

function Clear-LOSTrustEnforcementState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RootPath
    )

    $statePath = Write-LOSTrustEnforcementRecords -RootPath $RootPath -Records @()
    return [PSCustomObject][ordered]@{
        Success   = $true
        Cleared   = $true
        StatePath = $statePath
    }
}

function Invoke-LOSTrustEnforcement {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RootPath,

        [Parameter(Mandatory)]
        [string] $SubjectId,

        [int] $TrustScore = -1,

        [string] $TrustStatus = "",

        [string] $AlertSeverity = "",

        [string] $EvidenceHash = "",

        [AllowNull()]
        [object] $Policy,

        [string] $TimestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    )

    $decision = "Allow"
    $reason = "PolicyAllowed"
    $severity = "Info"

    if ($TrustStatus -eq "Revoked") {
        $decision = "Revoke"
        $reason = "TrustStatusRevoked"
        $severity = "Critical"
    }
    elseif ($TrustStatus -eq "Denied") {
        $decision = "Deny"
        $reason = "TrustStatusDenied"
        $severity = "Critical"
    }
    elseif ($AlertSeverity -eq "Critical") {
        $decision = "Quarantine"
        $reason = "CriticalAlert"
        $severity = "Critical"
    }
    elseif ($TrustScore -ge 0 -and $TrustScore -lt 40) {
        $decision = "Quarantine"
        $reason = "TrustScoreBelowThreshold"
        $severity = "Warning"
    }

    if ($decision -eq "Revoke") {
        $record = Revoke-LOSTrustSubject -RootPath $RootPath -SubjectId $SubjectId -Reason $reason -Severity $severity -Source "Invoke-LOSTrustEnforcement" -EvidenceHash $EvidenceHash -TimestampUtc $TimestampUtc
        $enforcementId = $record.EnforcementId
    }
    elseif ($decision -eq "Deny") {
        $record = Deny-LOSTrustSubject -RootPath $RootPath -SubjectId $SubjectId -Reason $reason -Severity $severity -Source "Invoke-LOSTrustEnforcement" -EvidenceHash $EvidenceHash -TimestampUtc $TimestampUtc
        $enforcementId = $record.EnforcementId
    }
    elseif ($decision -eq "Quarantine") {
        $record = Quarantine-LOSTrustSubject -RootPath $RootPath -SubjectId $SubjectId -Reason $reason -Severity $severity -Source "Invoke-LOSTrustEnforcement" -EvidenceHash $EvidenceHash -TimestampUtc $TimestampUtc
        $enforcementId = $record.EnforcementId
    }
    else {
        $enforcementId = New-LOSTrustEnforcementId -SubjectId $SubjectId -Action "Allow" -Reason $reason -TimestampUtc $TimestampUtc -EvidenceHash $EvidenceHash
    }

    return [PSCustomObject][ordered]@{
        SubjectId             = $SubjectId
        EnforcementDecision   = $decision
        Reason                = $reason
        EnforcementId         = $enforcementId
        TimestampUtc          = $TimestampUtc
    }
}

Export-ModuleMember -Function Invoke-LOSTrustEnforcement, Quarantine-LOSTrustSubject, Deny-LOSTrustSubject, Revoke-LOSTrustSubject, Get-LOSTrustEnforcementState, Clear-LOSTrustEnforcementState
