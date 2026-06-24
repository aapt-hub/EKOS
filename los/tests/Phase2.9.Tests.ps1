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

Set-StrictMode -Version Latest

$script:here = $PSScriptRoot
$script:repoRoot = (Resolve-Path (Join-Path $script:here "..\..")).Path
$script:trustRoot = Join-Path $script:repoRoot "los\trust"

Import-Module (Join-Path $script:trustRoot "LOS.TrustScoring.psm1") -Force -Global
Import-Module (Join-Path $script:trustRoot "LOS.TrustAlerts.psm1") -Force -Global
Import-Module (Join-Path $script:trustRoot "LOS.TrustLedger.psm1") -Force -Global
Import-Module (Join-Path $script:trustRoot "LOS.RuntimeTrustAuthority.psm1") -Force -Global
Import-Module (Join-Path $script:trustRoot "LOS.RuntimeTrustMonitor.psm1") -Force -Global

Describe "LOS Phase 2.9 Continuous Runtime Trust Monitoring" {
    BeforeAll {
        function New-TestMonitorRoot {
            $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("ekos-los-29-" + [guid]::NewGuid().ToString("N"))
            New-Item -ItemType Directory -Path (Join-Path $tempRoot "los\trust-data") -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $tempRoot "los\certification-data\ledger") -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $tempRoot "los\monitoring") -Force | Out-Null
            return $tempRoot
        }

        function Add-TestTrustRecord {
            param(
                [string] $RootPath,
                [string] $TrustId = "trust-29"
            )

            $entry = [PSCustomObject][ordered]@{
                TrustId           = $TrustId
                TimestampUtc      = "2026-06-23T00:00:00.0000000Z"
                Decision          = "ALLOW"
                TrustStatus       = "TRUSTED"
                Reason            = "TrustedRuntime"
                TrustEvidenceHash = "trust-hash-29"
            }
            Add-LOSTrustRecord -RootPath $RootPath -Entry $entry | Out-Null
        }

        function Add-TestCertificationRecord {
            param(
                [string] $RootPath,
                [string] $CertificationId = "cert-29",
                [string] $ExpirationUtc = ""
            )

            $entry = [ordered]@{
                CertificationId      = $CertificationId
                TimestampUtc          = "2026-06-23T00:00:00.0000000Z"
                EvidenceHash          = "evidence-hash-29"
                CertificationStatus   = "PASS"
            }
            if (-not [string]::IsNullOrWhiteSpace($ExpirationUtc)) {
                $entry["ExpirationUtc"] = $ExpirationUtc
            }

            $ledgerFile = Join-Path $RootPath "los\certification-data\ledger\certification-ledger.jsonl"
            Add-Content -LiteralPath $ledgerFile -Value (([PSCustomObject]$entry) | ConvertTo-Json -Depth 10 -Compress)
        }
    }

    It "calculates a full trust score" {
        $score = Get-LOSTrustScore `
            -TrustId "trust-score-full" `
            -Governance ([PSCustomObject][ordered]@{ Decision = "ALLOW" }) `
            -Certification ([PSCustomObject][ordered]@{ CertificationStatus = "PASS" }) `
            -RuntimeHealth ([PSCustomObject][ordered]@{ RuntimeHealth = "Healthy" }) `
            -HistoricalTrust ([PSCustomObject][ordered]@{ TrustStatus = "Trusted" }) `
            -TimestampUtc "2026-06-23T00:00:00.0000000Z"

        $score.Score | Should -Be 100
        $score.TrustStatus | Should -Be "Trusted"
    }

    It "calculates a degraded trust score" {
        $score = Get-LOSTrustScore `
            -TrustId "trust-score-degraded" `
            -Governance ([PSCustomObject][ordered]@{ Decision = "ALLOW" }) `
            -Certification $null `
            -RuntimeHealth ([PSCustomObject][ordered]@{ RuntimeHealth = "Degraded" }) `
            -HistoricalTrust $null `
            -TimestampUtc "2026-06-23T00:00:00.0000000Z"

        $score.Score | Should -Be 50
        $score.TrustStatus | Should -Be "Degraded"
    }

    It "fails closed when scoring evidence is missing" {
        $score = Get-LOSTrustScore -TrustId "trust-score-missing" -TimestampUtc "2026-06-23T00:00:00.0000000Z"

        $score.Score | Should -Be 0
        $score.TrustStatus | Should -Be "Untrusted"
    }

    It "creates trust alerts" {
        $tempRoot = New-TestMonitorRoot
        try {
            $alert = New-LOSTrustAlert -RootPath $tempRoot -AlertId "alert-1" -TrustId "trust-29" -Severity "Warning" -Type "ScoreDrop" -Source "Phase2.9.Tests" -Message "Trust score dropped." -Evidence ([PSCustomObject][ordered]@{ Score = 74 }) -TimestampUtc "2026-06-23T00:00:00.0000000Z"
            $alerts = @(Get-LOSTrustAlerts -RootPath $tempRoot)

            $alert.Status | Should -Be "Active"
            $alerts.Count | Should -Be 1
            $alerts[0].AlertId | Should -Be "alert-1"
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "resolves trust alerts by appending resolution records" {
        $tempRoot = New-TestMonitorRoot
        try {
            New-LOSTrustAlert -RootPath $tempRoot -AlertId "alert-2" -TrustId "trust-29" -Severity "Critical" -Type "ExpiredCertification" -Source "Phase2.9.Tests" -Message "Expired." -Evidence $null -TimestampUtc "2026-06-23T00:00:00.0000000Z" | Out-Null
            $resolution = Resolve-LOSTrustAlert -RootPath $tempRoot -AlertId "alert-2" -Message "Acknowledged" -TimestampUtc "2026-06-23T00:01:00.0000000Z"
            $alerts = @(Get-LOSTrustAlerts -RootPath $tempRoot)

            $resolution.Status | Should -Be "Resolved"
            $alerts.Count | Should -Be 2
            $alerts[0].Status | Should -Be "Active"
            $alerts[1].Status | Should -Be "Resolved"
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "monitor once creates health report" {
        $tempRoot = New-TestMonitorRoot
        try {
            Add-TestTrustRecord -RootPath $tempRoot
            Add-TestCertificationRecord -RootPath $tempRoot
            $result = Invoke-LOSTrustMonitorOnce -RootPath $tempRoot -TimestampUtc "2026-06-23T00:00:00.0000000Z"

            (Test-Path -LiteralPath $result.HealthPath) | Should -BeTrue
            $result.Health.RuntimeHealth | Should -Be "Healthy"
            $result.Health.AverageTrustScore | Should -Be 100
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "monitor once creates runtime event" {
        $tempRoot = New-TestMonitorRoot
        try {
            Add-TestTrustRecord -RootPath $tempRoot
            Add-TestCertificationRecord -RootPath $tempRoot
            $result = Invoke-LOSTrustMonitorOnce -RootPath $tempRoot -TimestampUtc "2026-06-23T00:00:00.0000000Z"
            $events = @(Get-Content -LiteralPath $result.EventPath)

            (Test-Path -LiteralPath $result.EventPath) | Should -BeTrue
            $events.Count | Should -Be 1
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "expired certification creates alert" {
        $tempRoot = New-TestMonitorRoot
        try {
            Add-TestTrustRecord -RootPath $tempRoot
            Add-TestCertificationRecord -RootPath $tempRoot -ExpirationUtc "2026-06-22T00:00:00.0000000Z"
            Invoke-LOSTrustMonitorOnce -RootPath $tempRoot -TimestampUtc "2026-06-23T00:00:00.0000000Z" | Out-Null
            $alerts = @(Get-LOSTrustAlerts -RootPath $tempRoot -Status "Active")

            $alerts.Count | Should -Be 1
            $alerts[0].Type | Should -Be "CertificationExpired"
            $alerts[0].Severity | Should -Be "Critical"
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "Get-LOSTrustHealth reads health file" {
        $tempRoot = New-TestMonitorRoot
        try {
            Add-TestTrustRecord -RootPath $tempRoot
            Add-TestCertificationRecord -RootPath $tempRoot
            Invoke-LOSTrustMonitorOnce -RootPath $tempRoot -TimestampUtc "2026-06-23T00:00:00.0000000Z" | Out-Null
            $health = Get-LOSTrustHealth -RootPath $tempRoot

            $health.RuntimeHealth | Should -Be "Healthy"
            $health.AverageTrustScore | Should -Be 100
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "existing M2.8 compatibility wrappers still work" {
        $tempRoot = New-TestMonitorRoot
        try {
            Add-TestTrustRecord -RootPath $tempRoot -TrustId "trust-wrapper-29"
            $ledger = @(Get-LOSTrustLedger -RootPath $tempRoot)
            $record = Get-LOSTrustRecord -RootPath $tempRoot -TrustId "trust-wrapper-29"
            $integrity = Test-LOSTrustLedgerIntegrity -RootPath $tempRoot

            $ledger.Count | Should -Be 1
            $record.TrustId | Should -Be "trust-wrapper-29"
            $integrity.Valid | Should -BeTrue
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }
}
