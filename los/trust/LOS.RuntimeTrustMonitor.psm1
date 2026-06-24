<#
.SYNOPSIS
LOS Runtime Trust Monitor.

.DESCRIPTION
Runs continuous or one-pass runtime trust monitoring, recalculates trust scores, emits alerts, writes runtime events, and updates trust health summaries.

Author: Abner Pauneto
Project: EKOS
Subsystem: LOS
Phase: M2.9
Status: Complete
#>
Set-StrictMode -Version Latest

$script:LOSTrustMonitorStopRequested = $false

function Get-LOSTrustMonitoringTimestamp {
    [CmdletBinding()]
    param()

    return (Get-Date).ToUniversalTime().ToString("o")
}

function Read-LOSJsonLines {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return @()
    }

    $rows = @()
    foreach ($line in @(Get-Content -LiteralPath $Path)) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }
        $rows += ($line | ConvertFrom-Json)
    }

    return $rows
}

function Write-LOSTrustRuntimeEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RootPath,

        [Parameter(Mandatory)]
        [object] $Event
    )

    $monitoringDir = Join-Path $RootPath "los\monitoring"
    if (-not (Test-Path -LiteralPath $monitoringDir)) {
        New-Item -ItemType Directory -Path $monitoringDir | Out-Null
    }

    $eventFile = Join-Path $monitoringDir "runtime-events.jsonl"
    Add-Content -LiteralPath $eventFile -Value ($Event | ConvertTo-Json -Depth 20 -Compress)
    return $eventFile
}

function Get-LOSTrustHealth {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RootPath
    )

    $healthPath = Join-Path $RootPath "los\monitoring\trust-health.json"
    if (-not (Test-Path -LiteralPath $healthPath)) {
        return [PSCustomObject][ordered]@{
            Success       = $false
            RuntimeHealth = "Critical"
            Reason        = "TrustHealthMissing"
        }
    }

    return (Get-Content -LiteralPath $healthPath -Raw | ConvertFrom-Json)
}

function Invoke-LOSTrustMonitorOnce {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RootPath,

        [string] $TimestampUtc = (Get-LOSTrustMonitoringTimestamp)
    )

    Import-Module (Join-Path $PSScriptRoot "LOS.TrustScoring.psm1") -Force -Global
    Import-Module (Join-Path $PSScriptRoot "LOS.TrustAlerts.psm1") -Force -Global

    $monitoringDir = Join-Path $RootPath "los\monitoring"
    if (-not (Test-Path -LiteralPath $monitoringDir)) {
        New-Item -ItemType Directory -Path $monitoringDir | Out-Null
    }

    $trustLedgerPath = Join-Path $RootPath "los\trust-data\trust-ledger.json"
    $certificationLedgerPath = Join-Path $RootPath "los\certification-data\ledger\certification-ledger.jsonl"
    $trustRows = @(Read-LOSJsonLines -Path $trustLedgerPath)
    $certificationRows = @(Read-LOSJsonLines -Path $certificationLedgerPath)

    $activeWarnings = 0
    $criticalAlerts = 0
    $expiredCertifications = 0
    $scores = @()

    if ($trustRows.Count -eq 0) {
        New-LOSTrustAlert -RootPath $RootPath -AlertId "missing-trust-evidence" -TrustId "global" -Severity "Critical" -Type "MissingTrustEvidence" -Source "Invoke-LOSTrustMonitorOnce" -Message "Trust evidence ledger is missing or empty." -Evidence ([PSCustomObject][ordered]@{ LedgerPath = $trustLedgerPath }) -TimestampUtc $TimestampUtc | Out-Null
        $criticalAlerts++
    }

    if ($certificationRows.Count -eq 0) {
        New-LOSTrustAlert -RootPath $RootPath -AlertId "missing-certification-evidence" -TrustId "global" -Severity "Warning" -Type "MissingCertificationEvidence" -Source "Invoke-LOSTrustMonitorOnce" -Message "Certification evidence ledger is missing or empty." -Evidence ([PSCustomObject][ordered]@{ LedgerPath = $certificationLedgerPath }) -TimestampUtc $TimestampUtc | Out-Null
        $activeWarnings++
    }

    foreach ($certification in $certificationRows) {
        if ($certification.PSObject.Properties.Name -contains "ExpirationUtc") {
            $expirationUtc = [datetime] $certification.ExpirationUtc
            $nowUtc = [datetime] $TimestampUtc
            if ($expirationUtc.ToUniversalTime() -lt $nowUtc.ToUniversalTime()) {
                $trustId = "global"
                if ($certification.PSObject.Properties.Name -contains "CertificationId") {
                    $trustId = [string] $certification.CertificationId
                }
                New-LOSTrustAlert -RootPath $RootPath -AlertId ("expired-certification-" + $trustId) -TrustId $trustId -Severity "Critical" -Type "CertificationExpired" -Source "Invoke-LOSTrustMonitorOnce" -Message "Certification evidence has expired." -Evidence $certification -TimestampUtc $TimestampUtc | Out-Null
                $criticalAlerts++
                $expiredCertifications++
            }
        }
    }

    foreach ($trust in $trustRows) {
        $trustId = "unknown"
        if ($trust.PSObject.Properties.Name -contains "TrustId") {
            $trustId = [string] $trust.TrustId
        }
        elseif ($trust.PSObject.Properties.Name -contains "TrustEvidenceHash") {
            $trustId = [string] $trust.TrustEvidenceHash
        }

        $governance = [PSCustomObject][ordered]@{ Decision = "ALLOW" }
        $certification = [PSCustomObject][ordered]@{ CertificationStatus = "PASS" }
        if ($certificationRows.Count -eq 0) {
            $certification = $null
        }

        $runtimeHealth = [PSCustomObject][ordered]@{ RuntimeHealth = "Healthy" }
        if ($criticalAlerts -gt 0) {
            $runtimeHealth = [PSCustomObject][ordered]@{ RuntimeHealth = "Critical" }
        }
        elseif ($activeWarnings -gt 0) {
            $runtimeHealth = [PSCustomObject][ordered]@{ RuntimeHealth = "Warning" }
        }

        $history = [PSCustomObject][ordered]@{ TrustStatus = "Trusted" }
        if ($trust.PSObject.Properties.Name -contains "TrustStatus" -and $trust.TrustStatus -ne "TRUSTED") {
            $history = [PSCustomObject][ordered]@{ TrustStatus = "Untrusted" }
        }

        $scores += (Get-LOSTrustScore -TrustId $trustId -Governance $governance -Certification $certification -RuntimeHealth $runtimeHealth -HistoricalTrust $history -TimestampUtc $TimestampUtc)
    }

    if ($scores.Count -eq 0) {
        $scores += (Get-LOSTrustScore -TrustId "global" -TimestampUtc $TimestampUtc)
    }

    $totalScore = 0
    foreach ($score in $scores) {
        $totalScore += [int] $score.Score
    }
    $averageTrustScore = [int] [System.Math]::Round($totalScore / $scores.Count)

    $runtimeHealthState = "Healthy"
    if ($criticalAlerts -gt 0) {
        $runtimeHealthState = "Critical"
    }
    elseif ($averageTrustScore -lt 50) {
        $runtimeHealthState = "Critical"
    }
    elseif ($averageTrustScore -lt 75) {
        $runtimeHealthState = "Degraded"
    }
    elseif ($activeWarnings -gt 0 -or $averageTrustScore -lt 90) {
        $runtimeHealthState = "Warning"
    }

    $certificationCoverage = 0
    if ($trustRows.Count -gt 0) {
        $certificationCoverage = [int] [System.Math]::Round(($certificationRows.Count / $trustRows.Count) * 100)
        if ($certificationCoverage -gt 100) {
            $certificationCoverage = 100
        }
    }
    elseif ($certificationRows.Count -gt 0) {
        $certificationCoverage = 100
    }

    $health = [PSCustomObject][ordered]@{
        TimestampUtc           = $TimestampUtc
        RuntimeHealth          = $runtimeHealthState
        AverageTrustScore      = $averageTrustScore
        ActiveWarnings         = $activeWarnings
        CriticalAlerts         = $criticalAlerts
        CertificationCoverage  = $certificationCoverage
        Evidence               = [PSCustomObject][ordered]@{
            TrustRecords          = $trustRows.Count
            CertificationRecords  = $certificationRows.Count
            ExpiredCertifications = $expiredCertifications
            Scores                = $scores
        }
    }

    $healthPath = Join-Path $monitoringDir "trust-health.json"
    Set-Content -LiteralPath $healthPath -Value ($health | ConvertTo-Json -Depth 30) -Encoding UTF8

    $event = [PSCustomObject][ordered]@{
        TimestampUtc      = $TimestampUtc
        Type              = "TrustMonitorPass"
        RuntimeHealth     = $runtimeHealthState
        AverageTrustScore = $averageTrustScore
    }
    $eventPath = Write-LOSTrustRuntimeEvent -RootPath $RootPath -Event $event

    return [PSCustomObject][ordered]@{
        Success     = ($runtimeHealthState -ne "Critical")
        Health      = $health
        HealthPath  = $healthPath
        EventPath   = $eventPath
    }
}

function Start-LOSTrustMonitor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RootPath,

        [int] $IntervalSeconds = 60,

        [switch] $Once
    )

    $script:LOSTrustMonitorStopRequested = $false
    if ($Once) {
        return Invoke-LOSTrustMonitorOnce -RootPath $RootPath
    }

    while (-not $script:LOSTrustMonitorStopRequested) {
        Invoke-LOSTrustMonitorOnce -RootPath $RootPath | Out-Null
        Start-Sleep -Seconds $IntervalSeconds
    }

    return [PSCustomObject][ordered]@{
        Success = $true
        Stopped = $true
    }
}

function Stop-LOSTrustMonitor {
    [CmdletBinding()]
    param()

    $script:LOSTrustMonitorStopRequested = $true
    return [PSCustomObject][ordered]@{
        Success = $true
        Stopped = $true
    }
}

Export-ModuleMember -Function Start-LOSTrustMonitor, Stop-LOSTrustMonitor, Invoke-LOSTrustMonitorOnce, Get-LOSTrustHealth
