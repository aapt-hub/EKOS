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
LOS Runtime Trust Dashboard.

.DESCRIPTION
Deterministic observability and reporting layer for LOS runtime trust state.
#>

Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'LOS.TrustDashboardModels.psm1') -Force -Global
Import-Module (Join-Path $PSScriptRoot 'LOS.TrustDashboardRenderer.psm1') -Force -Global

Import-Module (Join-Path $PSScriptRoot '..\trust\LOS.RuntimeTrustMonitor.psm1') -Force -Global
Import-Module (Join-Path $PSScriptRoot '..\trust\LOS.RuntimeTrustEnforcement.psm1') -Force -Global
Import-Module (Join-Path $PSScriptRoot '..\trust\LOS.TrustRecovery.psm1') -Force -Global
Import-Module (Join-Path $PSScriptRoot '..\trust\LOS.TrustAlerts.psm1') -Force -Global
Import-Module (Join-Path $PSScriptRoot '..\trust\LOS.TrustLedger.psm1') -Force -Global

function Resolve-LOSTrustDashboardRootPath {
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string] $RootPath
    )

    if (-not [string]::IsNullOrWhiteSpace($RootPath)) {
        return (Resolve-Path -LiteralPath $RootPath -ErrorAction Stop).Path
    }

    $moduleRoot = $PSScriptRoot
    if ([string]::IsNullOrWhiteSpace($moduleRoot) -and -not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
        $moduleRoot = Split-Path -Parent $PSCommandPath
    }

    if ([string]::IsNullOrWhiteSpace($moduleRoot)) {
        throw 'RootPathResolutionFailed'
    }

    return (Resolve-Path -LiteralPath (Join-Path $moduleRoot '..\..') -ErrorAction Stop).Path
}

function Get-LOSTrustDashboardPolicyRegistry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RootPath
    )

    $policyDir = Join-Path $RootPath 'los\policies'
    $registryStatus = 'Missing'
    $reason = 'PolicyDirectoryMissing'
    $loadedPolicies = @()
    $activePolicies = @()

    if (Test-Path -LiteralPath $policyDir) {
        $policyFiles = @(Get-ChildItem -LiteralPath $policyDir -Filter '*.json' -File | Sort-Object Name)
        if ($policyFiles.Count -eq 0) {
            $registryStatus = 'Empty'
            $reason = 'PolicyDirectoryEmpty'
        }
        else {
            $registryStatus = 'Loaded'
            $reason = 'PoliciesLoaded'
            foreach ($file in $policyFiles) {
                try {
                    $policy = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
                    $enabled = $false
                    if ($policy.PSObject.Properties.Name -contains 'Enabled') {
                        $enabled = ($policy.Enabled -eq $true)
                    }
                    $entry = [PSCustomObject][ordered]@{
                        PolicyId = if ($policy.PSObject.Properties.Name -contains 'PolicyId') { [string]$policy.PolicyId } else { $file.BaseName }
                        Name     = if ($policy.PSObject.Properties.Name -contains 'Name') { [string]$policy.Name } else { $file.BaseName }
                        Version  = if ($policy.PSObject.Properties.Name -contains 'Version') { [string]$policy.Version } else { '' }
                        Enabled  = $enabled
                        Source   = $file.FullName
                    }
                    $loadedPolicies += $entry
                    if ($enabled) {
                        $activePolicies += $entry
                    }
                }
                catch {
                    $registryStatus = 'Degraded'
                    $reason = 'PolicyLoadError'
                }
            }
        }
    }

    return [PSCustomObject][ordered]@{
        PolicyDirectory    = $policyDir
        RegistryStatus     = $registryStatus
        Reason             = $reason
        LoadedPolicies     = @($loadedPolicies | Sort-Object PolicyId, Name, Version)
        ActivePolicies     = @($activePolicies | Sort-Object PolicyId, Name, Version)
        LoadedPolicyCount  = @($loadedPolicies).Count
        ActivePolicyCount  = @($activePolicies).Count
    }
}

function Get-LOSTrustDashboardHealth {
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string] $RootPath = '.'
    )

    $resolvedRoot = Resolve-LOSTrustDashboardRootPath -RootPath $RootPath
    $health = Get-LOSTrustHealth -RootPath $resolvedRoot
    $runtimeHealth = 'Critical'
    if ($null -ne $health -and $health.PSObject.Properties.Name -contains 'RuntimeHealth' -and -not [string]::IsNullOrWhiteSpace([string]$health.RuntimeHealth)) {
        $runtimeHealth = [string]$health.RuntimeHealth
    }

    $trustScore = 0
    if ($null -ne $health -and $health.PSObject.Properties.Name -contains 'AverageTrustScore') {
        $scoreValue = $health.AverageTrustScore
        if ($scoreValue -is [int] -or $scoreValue -is [long] -or $scoreValue -is [double] -or $scoreValue -is [decimal]) {
            $trustScore = [double]$scoreValue
        }
        elseif ($null -ne $scoreValue) {
            $parsed = 0.0
            if ([double]::TryParse([string]$scoreValue, [ref]$parsed)) {
                $trustScore = $parsed
            }
        }
    }

    return [PSCustomObject][ordered]@{
        RootPath      = $resolvedRoot
        RuntimeHealth = $runtimeHealth
        TrustScore    = $trustScore
        Health        = $health
    }
}

function Get-LOSTrustDashboardAlerts {
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string] $RootPath = '.'
    )

    $resolvedRoot = Resolve-LOSTrustDashboardRootPath -RootPath $RootPath
    $alerts = @(Get-LOSTrustAlerts -RootPath $resolvedRoot)
    $activeAlerts = @($alerts | Where-Object { $_.PSObject.Properties.Name -contains 'Status' -and $_.Status -eq 'Active' })
    $resolvedAlerts = @($alerts | Where-Object { $_.PSObject.Properties.Name -contains 'Status' -and $_.Status -eq 'Resolved' })

    $critical = @($alerts | Where-Object { $_.PSObject.Properties.Name -contains 'Severity' -and $_.Severity -eq 'Critical' })
    $warning = @($alerts | Where-Object { $_.PSObject.Properties.Name -contains 'Severity' -and $_.Severity -eq 'Warning' })
    $info = @($alerts | Where-Object { $_.PSObject.Properties.Name -contains 'Severity' -and $_.Severity -eq 'Info' })

    return [PSCustomObject][ordered]@{
        RootPath = $resolvedRoot
        Alerts   = @($alerts | Sort-Object TimestampUtc, AlertId)
        Summary  = [PSCustomObject][ordered]@{
            Total    = @($alerts).Count
            Active   = @($activeAlerts).Count
            Resolved = @($resolvedAlerts).Count
            Critical = @($critical).Count
            Warning  = @($warning).Count
            Info     = @($info).Count
        }
    }
}

function Get-LOSTrustDashboardSummary {
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string] $RootPath = '.'
    )

    $resolvedRoot = Resolve-LOSTrustDashboardRootPath -RootPath $RootPath
    $healthInfo = Get-LOSTrustDashboardHealth -RootPath $resolvedRoot
    $policyInfo = Get-LOSTrustDashboardPolicyRegistry -RootPath $resolvedRoot
    $alertsInfo = Get-LOSTrustDashboardAlerts -RootPath $resolvedRoot
    $enforcementState = Get-LOSTrustEnforcementState -RootPath $resolvedRoot
    $recoveryState = Get-LOSTrustRecoveryState -RootPath $resolvedRoot
    $trustLedger = @(Get-LOSTrustLedger -RootPath $resolvedRoot)

    $latestDecisions = @(
        $trustLedger |
            Sort-Object TimestampUtc, TrustEvidenceHash, Decision |
            Select-Object -Last 5
    )
    $normalizedDecisions = @()
    foreach ($decision in $latestDecisions) {
        $normalizedDecisions += [PSCustomObject][ordered]@{
            TimestampUtc     = if ($decision.PSObject.Properties.Name -contains 'TimestampUtc') { [string]$decision.TimestampUtc } else { '' }
            TrustId          = if ($decision.PSObject.Properties.Name -contains 'TrustId') { [string]$decision.TrustId } else { '' }
            Decision         = if ($decision.PSObject.Properties.Name -contains 'Decision') { [string]$decision.Decision } else { 'DENY' }
            TrustStatus      = if ($decision.PSObject.Properties.Name -contains 'TrustStatus') { [string]$decision.TrustStatus } else { 'UNTRUSTED' }
            TrustEvidenceHash = if ($decision.PSObject.Properties.Name -contains 'TrustEvidenceHash') { [string]$decision.TrustEvidenceHash } else { '' }
        }
    }

    $enforcementRecords = @()
    if ($null -ne $enforcementState -and $enforcementState.PSObject.Properties.Name -contains 'Records') {
        $enforcementRecords = @($enforcementState.Records)
    }

    $recoveryRequests = @()
    if ($null -ne $recoveryState -and $recoveryState.PSObject.Properties.Name -contains 'Requests') {
        $recoveryRequests = @($recoveryState.Requests)
    }

    $subjects = @()
    foreach ($entry in $trustLedger) {
        if ($entry.PSObject.Properties.Name -contains 'TrustId' -and -not [string]::IsNullOrWhiteSpace([string]$entry.TrustId)) {
            $subjects += [string]$entry.TrustId
        }
    }
    foreach ($entry in $enforcementRecords) {
        if ($entry.PSObject.Properties.Name -contains 'SubjectId' -and -not [string]::IsNullOrWhiteSpace([string]$entry.SubjectId)) {
            $subjects += [string]$entry.SubjectId
        }
    }
    foreach ($entry in $recoveryRequests) {
        if ($entry.PSObject.Properties.Name -contains 'TrustId' -and -not [string]::IsNullOrWhiteSpace([string]$entry.TrustId)) {
            $subjects += [string]$entry.TrustId
        }
    }

    $subjects = @($subjects | Sort-Object -Unique)

    $quarantinedSubjects = @($enforcementRecords | Where-Object { $_.Action -eq 'Quarantine' } | Select-Object -ExpandProperty SubjectId -Unique)
    $revokedSubjects = @($enforcementRecords | Where-Object { $_.Action -eq 'Revoke' } | Select-Object -ExpandProperty SubjectId -Unique)
    $deniedSubjects = @($enforcementRecords | Where-Object { $_.Action -eq 'Deny' } | Select-Object -ExpandProperty SubjectId -Unique)
    $recoveringSubjects = @($recoveryRequests | Where-Object {
        $_.PSObject.Properties.Name -contains 'CurrentState' -and $_.CurrentState -notin @('Active', 'RecoveryRejected')
    } | Select-Object -ExpandProperty TrustId -Unique)
    $activeSubjects = @($subjects | Where-Object {
        $_ -notin $quarantinedSubjects -and
        $_ -notin $revokedSubjects -and
        $_ -notin $deniedSubjects -and
        $_ -notin $recoveringSubjects
    })

    $summary = [PSCustomObject][ordered]@{
        RootPath              = $resolvedRoot
        RuntimeHealth         = $healthInfo.RuntimeHealth
        TrustScore            = $healthInfo.TrustScore
        PolicyRegistryStatus   = $policyInfo.RegistryStatus
        PolicyRegistryReason    = $policyInfo.Reason
        PolicyDirectory        = $policyInfo.PolicyDirectory
        LoadedPolicyCount      = $policyInfo.LoadedPolicyCount
        ActivePolicyCount      = $policyInfo.ActivePolicyCount
        ActivePolicies         = $policyInfo.ActivePolicies
        RuntimeSubjects        = [PSCustomObject][ordered]@{
            Total      = @($subjects).Count
            Active     = @($activeSubjects).Count
            Quarantined = @($quarantinedSubjects).Count
            Revoked    = @($revokedSubjects).Count
            Recovering = @($recoveringSubjects).Count
        }
        LatestPolicyDecisions  = @($normalizedDecisions)
        EnforcementSummary     = [PSCustomObject][ordered]@{
            Total      = @($enforcementRecords).Count
            Quarantine = @($quarantinedSubjects).Count
            Deny       = @($deniedSubjects).Count
            Revoke     = @($revokedSubjects).Count
        }
        RecoverySummary        = [PSCustomObject][ordered]@{
            Total      = @($recoveryRequests).Count
            Active     = @($recoveryRequests | Where-Object { $_.PSObject.Properties.Name -contains 'CurrentState' -and $_.CurrentState -eq 'Active' }).Count
            Recovering = @($recoveringSubjects).Count
            Approved   = @($recoveryRequests | Where-Object { $_.PSObject.Properties.Name -contains 'CurrentState' -and $_.CurrentState -eq 'Active' }).Count
            Denied     = @($recoveryRequests | Where-Object { $_.PSObject.Properties.Name -contains 'CurrentState' -and $_.CurrentState -eq 'RecoveryRejected' }).Count
        }
        AlertSummary           = $alertsInfo.Summary
    }

    $summary | Add-Member -NotePropertyName ReportHash -NotePropertyValue (Get-LOSTrustDashboardHash -InputObject $summary) -Force
    return $summary
}

function Get-LOSTrustDashboard {
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string] $RootPath = '.'
    )

    $resolvedRoot = Resolve-LOSTrustDashboardRootPath -RootPath $RootPath
    $summary = Get-LOSTrustDashboardSummary -RootPath $resolvedRoot
    $health = Get-LOSTrustDashboardHealth -RootPath $resolvedRoot
    $alerts = Get-LOSTrustDashboardAlerts -RootPath $resolvedRoot
    $policyInfo = Get-LOSTrustDashboardPolicyRegistry -RootPath $resolvedRoot
    $enforcementState = Get-LOSTrustEnforcementState -RootPath $resolvedRoot
    $recoveryState = Get-LOSTrustRecoveryState -RootPath $resolvedRoot
    $trustLedger = @(Get-LOSTrustLedger -RootPath $resolvedRoot)

    return [PSCustomObject][ordered]@{
        Summary             = $summary
        Health              = $health
        PolicyRegistry      = $policyInfo
        LatestPolicyDecisions = $summary.LatestPolicyDecisions
        RuntimeSubjects     = $summary.RuntimeSubjects
        EnforcementSummary  = $summary.EnforcementSummary
        RecoverySummary     = $summary.RecoverySummary
        AlertSummary        = $summary.AlertSummary
        Alerts              = $alerts.Alerts
        TrustLedger         = $trustLedger
        EnforcementState    = $enforcementState
        RecoveryState       = $recoveryState
        ReportHash          = $summary.ReportHash
    }
}

function Export-LOSTrustDashboardReport {
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string] $RootPath = '.',

        [AllowEmptyString()]
        [string] $Path = ''
    )

    $resolvedRoot = Resolve-LOSTrustDashboardRootPath -RootPath $RootPath
    $dashboard = Get-LOSTrustDashboard -RootPath $resolvedRoot
    $json = ConvertTo-LOSTrustDashboardJson -Dashboard $dashboard

    $outputPath = $Path
    if ([string]::IsNullOrWhiteSpace($outputPath)) {
        $reportDir = Join-Path $resolvedRoot 'los\reports'
        if (-not (Test-Path -LiteralPath $reportDir)) {
            New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
        }
        $outputPath = Join-Path $reportDir 'trust-dashboard.json'
    }
    else {
        $parentDir = Split-Path -Parent $outputPath
        if (-not [string]::IsNullOrWhiteSpace($parentDir) -and -not (Test-Path -LiteralPath $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }
    }

    [System.IO.File]::WriteAllText($outputPath, $json, [System.Text.UTF8Encoding]::new($false))

    return [PSCustomObject][ordered]@{
        Success    = $true
        OutputPath = $outputPath
        ReportHash = $dashboard.ReportHash
        Dashboard  = $dashboard
    }
}

Export-ModuleMember -Function Get-LOSTrustDashboard, Get-LOSTrustDashboardSummary, Get-LOSTrustDashboardHealth, Get-LOSTrustDashboardAlerts, Export-LOSTrustDashboardReport
