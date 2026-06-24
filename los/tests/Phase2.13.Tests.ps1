<#
AUTHOR:
Abner Pauneto

COPYRIGHT:
Copyright (c) 2026 Abner Pauneto

LICENSE:
Proprietary - All Rights Reserved

PROJECT:
EKOS

STATUS:
Private Development
#>

Set-StrictMode -Version Latest

$script:here = $PSScriptRoot
$script:repoRoot = (Resolve-Path (Join-Path $script:here '..\..')).Path
$script:dashboardRoot = Join-Path $script:repoRoot 'los\dashboard'
$script:trustRoot = Join-Path $script:repoRoot 'los\trust'

Import-Module (Join-Path $script:dashboardRoot 'LOS.RuntimeTrustDashboard.psm1') -Force -Global
Import-Module (Join-Path $script:trustRoot 'LOS.RuntimeTrustEnforcement.psm1') -Force -Global
Import-Module (Join-Path $script:trustRoot 'LOS.TrustRecovery.psm1') -Force -Global
Import-Module (Join-Path $script:trustRoot 'LOS.TrustAlerts.psm1') -Force -Global
Import-Module (Join-Path $script:trustRoot 'LOS.TrustLedger.psm1') -Force -Global

Describe 'LOS Phase 2.13 Runtime Trust Dashboard' {
    BeforeAll {
        function New-TestDashboardRoot {
            $root = Join-Path ([System.IO.Path]::GetTempPath()) ('ekos-los-213-' + [guid]::NewGuid().ToString('N'))
            foreach ($path in @(
                'los',
                'los\trust-data',
                'los\trust\data',
                'los\trust\ledger',
                'los\monitoring',
                'los\policies'
            )) {
                New-Item -ItemType Directory -Path (Join-Path $root $path) -Force | Out-Null
            }

            return $root
        }

        function Write-TestJson {
            param(
                [Parameter(Mandatory)]
                [string] $Path,

                [Parameter(Mandatory)]
                [object] $InputObject
            )

            $json = $InputObject | ConvertTo-Json -Depth 20
            [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
        }

        function Add-TestPolicy {
            param(
                [Parameter(Mandatory)]
                [string] $RootPath,

                [Parameter(Mandatory)]
                [string] $PolicyFileName,

                [Parameter(Mandatory)]
                [string] $PolicyId,

                [Parameter(Mandatory)]
                [bool] $Enabled
            )

            $policy = [PSCustomObject][ordered]@{
                PolicyId = $PolicyId
                Name = $PolicyId
                Version = '1.0.0'
                Enabled = $Enabled
                Scope = [PSCustomObject][ordered]@{
                    SubjectType = 'RuntimeAuthorized'
                }
                Conditions = @(
                    [PSCustomObject][ordered]@{
                        Field = 'RuntimeAuthorized'
                        Operator = 'Equals'
                        Value = $true
                    }
                )
                Actions = @(
                    [PSCustomObject][ordered]@{
                        Outcome = 'Allow'
                        Severity = 'Info'
                        Reason = 'UnitTest'
                    }
                )
                Severity = 'Info'
                CreatedBy = 'unit'
                CreatedUtc = '2026-06-24T00:00:00.0000000Z'
            }

            Write-TestJson -Path (Join-Path $RootPath ('los\policies\' + $PolicyFileName)) -InputObject $policy
        }

        function Add-TestTrustDecision {
            param(
                [Parameter(Mandatory)]
                [string] $RootPath,

                [Parameter(Mandatory)]
                [string] $TrustId,

                [Parameter(Mandatory)]
                [string] $Decision,

                [Parameter(Mandatory)]
                [string] $TrustStatus,

                [Parameter(Mandatory)]
                [string] $TrustEvidenceHash,

                [Parameter(Mandatory)]
                [string] $TimestampUtc
            )

            Add-LOSTrustRecord -RootPath $RootPath -Entry ([PSCustomObject][ordered]@{
                TimestampUtc = $TimestampUtc
                TrustId = $TrustId
                PolicyId = 'dashboard-policy-001'
                Decision = $Decision
                TrustStatus = $TrustStatus
                TrustEvidenceHash = $TrustEvidenceHash
            }) | Out-Null
        }

        function Seed-PopulatedDashboardState {
            param(
                [Parameter(Mandatory)]
                [string] $RootPath
            )

            Add-TestPolicy -RootPath $RootPath -PolicyFileName 'PolicyA.json' -PolicyId 'dashboard-policy-001' -Enabled $true
            Add-TestPolicy -RootPath $RootPath -PolicyFileName 'PolicyB.json' -PolicyId 'dashboard-policy-002' -Enabled $false

            Write-TestJson -Path (Join-Path $RootPath 'los\monitoring\trust-health.json') -InputObject ([PSCustomObject][ordered]@{
                Success = $true
                RuntimeHealth = 'Healthy'
                Reason = 'TrustHealthStable'
                AverageTrustScore = 91
                ActiveWarnings = 1
                CriticalAlerts = 0
                ExpiredCertifications = 0
            })

            Add-TestTrustDecision -RootPath $RootPath -TrustId 'runtime-active' -Decision 'ALLOW' -TrustStatus 'Trusted' -TrustEvidenceHash 'hash-a' -TimestampUtc '2026-06-24T00:00:00.0000000Z'
            Add-TestTrustDecision -RootPath $RootPath -TrustId 'runtime-quarantined' -Decision 'DENY' -TrustStatus 'Quarantined' -TrustEvidenceHash 'hash-b' -TimestampUtc '2026-06-24T00:00:01.0000000Z'
            Add-TestTrustDecision -RootPath $RootPath -TrustId 'runtime-revoked' -Decision 'DENY' -TrustStatus 'Revoked' -TrustEvidenceHash 'hash-c' -TimestampUtc '2026-06-24T00:00:02.0000000Z'
            Add-TestTrustDecision -RootPath $RootPath -TrustId 'runtime-recovering' -Decision 'DENY' -TrustStatus 'Untrusted' -TrustEvidenceHash 'hash-d' -TimestampUtc '2026-06-24T00:00:03.0000000Z'

            Quarantine-LOSTrustSubject -RootPath $RootPath -SubjectId 'runtime-quarantined' -Reason 'UnitTestQuarantine' -Severity 'Warning' -EvidenceHash 'enf-q' -TimestampUtc '2026-06-24T00:00:10.0000000Z' | Out-Null
            Revoke-LOSTrustSubject -RootPath $RootPath -SubjectId 'runtime-revoked' -Reason 'UnitTestRevoke' -Severity 'Critical' -EvidenceHash 'enf-r' -TimestampUtc '2026-06-24T00:00:11.0000000Z' | Out-Null

            Request-LOSTrustRecovery -RootPath $RootPath -TrustId 'runtime-recovering' -Reason 'Remediate' -Evidence ([PSCustomObject][ordered]@{
                CertificationStatus = 'Passed'
                AttestationStatus = 'Valid'
                PolicyStatus = 'Compliant'
                IntegrityStatus = 'Passed'
            }) -RequestedBy 'RuntimeOperator' -CurrentState 'Quarantined' -TimestampUtc '2026-06-24T00:00:12.0000000Z' | Out-Null

            New-LOSTrustAlert -RootPath $RootPath -AlertId 'alert-critical' -TrustId 'runtime-quarantined' -Severity 'Critical' -Type 'CriticalAlert' -Source 'UnitTest' -Message 'Critical alert' -Evidence ([PSCustomObject][ordered]@{ Stage = 'critical' }) -TimestampUtc '2026-06-24T00:00:13.0000000Z' | Out-Null
            Resolve-LOSTrustAlert -RootPath $RootPath -AlertId 'alert-critical' -Message 'Resolved' -TimestampUtc '2026-06-24T00:00:14.0000000Z' | Out-Null
            New-LOSTrustAlert -RootPath $RootPath -AlertId 'alert-info' -TrustId 'runtime-active' -Severity 'Info' -Type 'InfoAlert' -Source 'UnitTest' -Message 'Info alert' -Evidence ([PSCustomObject][ordered]@{ Stage = 'info' }) -TimestampUtc '2026-06-24T00:00:15.0000000Z' | Out-Null
        }
    }

    It 'exports required commands' {
        Get-Command Get-LOSTrustDashboard | Should -Not -BeNullOrEmpty
        Get-Command Get-LOSTrustDashboardSummary | Should -Not -BeNullOrEmpty
        Get-Command Get-LOSTrustDashboardHealth | Should -Not -BeNullOrEmpty
        Get-Command Get-LOSTrustDashboardAlerts | Should -Not -BeNullOrEmpty
        Get-Command Export-LOSTrustDashboardReport | Should -Not -BeNullOrEmpty
    }

    It 'accepts an empty RootPath without parameter binding failure' {
        { Get-LOSTrustDashboardSummary -RootPath '' | Out-Null } | Should -Not -Throw
    }

    It 'fails closed on empty registry and empty alerts' {
        $root = New-TestDashboardRoot
        try {
            Remove-Item -LiteralPath (Join-Path $root 'los\policies') -Recurse -Force

            $summary = Get-LOSTrustDashboardSummary -RootPath $root
            $alerts = Get-LOSTrustDashboardAlerts -RootPath $root
            $health = Get-LOSTrustDashboardHealth -RootPath $root

            ($summary.PolicyRegistryStatus -in @('Missing', 'Empty')) | Should -BeTrue
            $summary.LoadedPolicyCount | Should -Be 0
            $summary.ActivePolicyCount | Should -Be 0
            $summary.RuntimeHealth | Should -Be 'Critical'
            $summary.RuntimeSubjects.Total | Should -Be 0
            $alerts.Summary.Total | Should -Be 0
            $alerts.Alerts.Count | Should -Be 0
            $health.RuntimeHealth | Should -Be 'Critical'
        }
        finally {
            Remove-Item -LiteralPath $root -Recurse -Force
        }
    }

    It 'summarizes populated runtime behavior deterministically' {
        $root = New-TestDashboardRoot
        try {
            Seed-PopulatedDashboardState -RootPath $root

            $first = Get-LOSTrustDashboard -RootPath $root
            $second = Get-LOSTrustDashboard -RootPath $root
            $firstJson = ConvertTo-LOSTrustDashboardJson -Dashboard $first
            $secondJson = ConvertTo-LOSTrustDashboardJson -Dashboard $second

            $firstJson | Should -Be $secondJson
            $first.ReportHash | Should -Be $second.ReportHash

            $first.Summary.RuntimeHealth | Should -Be 'Healthy'
            $first.Summary.TrustScore | Should -Be 91
            $first.Summary.PolicyRegistryStatus | Should -Be 'Loaded'
            $first.Summary.LoadedPolicyCount | Should -Be 2
            $first.Summary.ActivePolicyCount | Should -Be 1
            $first.Summary.RuntimeSubjects.Total | Should -Be 4
            $first.Summary.RuntimeSubjects.Active | Should -Be 1
            $first.Summary.RuntimeSubjects.Quarantined | Should -Be 1
            $first.Summary.RuntimeSubjects.Revoked | Should -Be 1
            $first.Summary.RuntimeSubjects.Recovering | Should -Be 1
            $first.Summary.LatestPolicyDecisions.Count | Should -Be 4
            $first.Summary.LatestPolicyDecisions[-1].TrustId | Should -Be 'runtime-recovering'
            $first.Summary.EnforcementSummary.Total | Should -Be 2
            $first.Summary.EnforcementSummary.Quarantine | Should -Be 1
            $first.Summary.EnforcementSummary.Revoke | Should -Be 1
            $first.Summary.RecoverySummary.Total | Should -Be 1
            $first.Summary.RecoverySummary.Recovering | Should -Be 1
            $first.Summary.AlertSummary.Total | Should -Be 3
            $first.Summary.AlertSummary.Active | Should -Be 2
            $first.Summary.AlertSummary.Resolved | Should -Be 1
            $first.Summary.AlertSummary.Critical | Should -Be 2
            $first.Summary.AlertSummary.Info | Should -Be 1
        }
        finally {
            Remove-Item -LiteralPath $root -Recurse -Force
        }
    }

    It 'exports a stable JSON report' {
        $root = New-TestDashboardRoot
        $outputPath = Join-Path $root 'dashboard.json'
        try {
            Seed-PopulatedDashboardState -RootPath $root

            $firstExport = Export-LOSTrustDashboardReport -RootPath $root -Path $outputPath
            $firstJson = Get-Content -LiteralPath $outputPath -Raw
            $secondExport = Export-LOSTrustDashboardReport -RootPath $root -Path $outputPath
            $secondJson = Get-Content -LiteralPath $outputPath -Raw

            $firstJson | Should -Be $secondJson
            $firstExport.ReportHash | Should -Be $secondExport.ReportHash
            $firstExport.OutputPath | Should -Be $outputPath
            ($firstJson | ConvertFrom-Json).ReportHash | Should -Be $firstExport.ReportHash
        }
        finally {
            Remove-Item -LiteralPath $root -Recurse -Force
        }
    }

    It 'keeps empty alerts deterministic' {
        $root = New-TestDashboardRoot
        try {
            $alerts = Get-LOSTrustDashboardAlerts -RootPath $root

            $alerts.Alerts.Count | Should -Be 0
            $alerts.Summary.Total | Should -Be 0
            $alerts.Summary.Active | Should -Be 0
            $alerts.Summary.Resolved | Should -Be 0
        }
        finally {
            Remove-Item -LiteralPath $root -Recurse -Force
        }
    }
}
