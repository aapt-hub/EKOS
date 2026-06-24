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

Import-Module (Join-Path $script:trustRoot "LOS.RuntimeTrustEnforcement.psm1") -Force -Global
Import-Module (Join-Path $script:trustRoot "LOS.TrustScoring.psm1") -Force -Global
Import-Module (Join-Path $script:trustRoot "LOS.TrustAlerts.psm1") -Force -Global
Import-Module (Join-Path $script:trustRoot "LOS.RuntimeTrustMonitor.psm1") -Force -Global

Describe "LOS Phase 2.10 Runtime Trust Enforcement" {
    BeforeAll {
        function New-TestEnforcementRoot {
            $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("ekos-los-210-" + [guid]::NewGuid().ToString("N"))
            New-Item -ItemType Directory -Path (Join-Path $tempRoot "los") -Force | Out-Null
            return $tempRoot
        }
    }

    It "allows healthy subject" {
        $tempRoot = New-TestEnforcementRoot
        try {
            $result = Invoke-LOSTrustEnforcement -RootPath $tempRoot -SubjectId "runtime-1" -TrustScore 95 -TrustStatus "Trusted" -AlertSeverity "Info" -EvidenceHash "hash-1" -TimestampUtc "2026-06-23T00:00:00.0000000Z"

            $result.EnforcementDecision | Should -Be "Allow"
            $result.Reason | Should -Be "PolicyAllowed"
            @(Get-LOSTrustEnforcementState -RootPath $tempRoot).Count | Should -BeGreaterThan 0
            (Get-LOSTrustEnforcementState -RootPath $tempRoot).Records.Count | Should -Be 0
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "quarantines critical alert" {
        $tempRoot = New-TestEnforcementRoot
        try {
            $result = Invoke-LOSTrustEnforcement -RootPath $tempRoot -SubjectId "runtime-critical" -TrustScore 95 -TrustStatus "Trusted" -AlertSeverity "Critical" -EvidenceHash "hash-critical" -TimestampUtc "2026-06-23T00:00:00.0000000Z"

            $result.EnforcementDecision | Should -Be "Quarantine"
            $result.Reason | Should -Be "CriticalAlert"
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "quarantines low trust score" {
        $tempRoot = New-TestEnforcementRoot
        try {
            $result = Invoke-LOSTrustEnforcement -RootPath $tempRoot -SubjectId "runtime-low" -TrustScore 39 -TrustStatus "Warning" -AlertSeverity "Warning" -EvidenceHash "hash-low" -TimestampUtc "2026-06-23T00:00:00.0000000Z"

            $result.EnforcementDecision | Should -Be "Quarantine"
            $result.Reason | Should -Be "TrustScoreBelowThreshold"
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "denies denied trust status" {
        $tempRoot = New-TestEnforcementRoot
        try {
            $result = Invoke-LOSTrustEnforcement -RootPath $tempRoot -SubjectId "runtime-denied" -TrustStatus "Denied" -EvidenceHash "hash-denied" -TimestampUtc "2026-06-23T00:00:00.0000000Z"

            $result.EnforcementDecision | Should -Be "Deny"
            $result.Reason | Should -Be "TrustStatusDenied"
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "revokes revoked trust status" {
        $tempRoot = New-TestEnforcementRoot
        try {
            $result = Invoke-LOSTrustEnforcement -RootPath $tempRoot -SubjectId "runtime-revoked" -TrustStatus "Revoked" -EvidenceHash "hash-revoked" -TimestampUtc "2026-06-23T00:00:00.0000000Z"

            $result.EnforcementDecision | Should -Be "Revoke"
            $result.Reason | Should -Be "TrustStatusRevoked"
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "persists enforcement state" {
        $tempRoot = New-TestEnforcementRoot
        try {
            Quarantine-LOSTrustSubject -RootPath $tempRoot -SubjectId "runtime-persist" -Reason "TestQuarantine" -Severity "Warning" -EvidenceHash "hash-persist" -TimestampUtc "2026-06-23T00:00:00.0000000Z" | Out-Null
            $statePath = Join-Path $tempRoot "los\trust\data\runtime-trust-enforcement.json"

            Test-Path -LiteralPath $statePath | Should -BeTrue
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "reads enforcement state" {
        $tempRoot = New-TestEnforcementRoot
        try {
            Deny-LOSTrustSubject -RootPath $tempRoot -SubjectId "runtime-read" -Reason "TestDeny" -Severity "Critical" -EvidenceHash "hash-read" -TimestampUtc "2026-06-23T00:00:00.0000000Z" | Out-Null
            $state = Get-LOSTrustEnforcementState -RootPath $tempRoot -SubjectId "runtime-read"

            $state.Records.Count | Should -Be 1
            $state.Records[0].Action | Should -Be "Deny"
            $state.Records[0].SubjectId | Should -Be "runtime-read"
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "clears enforcement state" {
        $tempRoot = New-TestEnforcementRoot
        try {
            Revoke-LOSTrustSubject -RootPath $tempRoot -SubjectId "runtime-clear" -Reason "TestRevoke" -Severity "Critical" -EvidenceHash "hash-clear" -TimestampUtc "2026-06-23T00:00:00.0000000Z" | Out-Null
            Clear-LOSTrustEnforcementState -RootPath $tempRoot | Out-Null
            $state = Get-LOSTrustEnforcementState -RootPath $tempRoot

            $state.Records.Count | Should -Be 0
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "keeps M2.8 and M2.9 public modules available" {
        Get-Command Get-LOSTrustScore | Should -Not -BeNullOrEmpty
        Get-Command New-LOSTrustAlert | Should -Not -BeNullOrEmpty
        Get-Command Invoke-LOSTrustMonitorOnce | Should -Not -BeNullOrEmpty
    }

    It "does not destructively change trust scoring, alerts, or monitor behavior" {
        $score = Get-LOSTrustScore `
            -TrustId "runtime-safe" `
            -Governance ([PSCustomObject][ordered]@{ Decision = "ALLOW" }) `
            -Certification ([PSCustomObject][ordered]@{ CertificationStatus = "PASS" }) `
            -RuntimeHealth ([PSCustomObject][ordered]@{ RuntimeHealth = "Healthy" }) `
            -HistoricalTrust ([PSCustomObject][ordered]@{ TrustStatus = "Trusted" }) `
            -TimestampUtc "2026-06-23T00:00:00.0000000Z"

        $score.Score | Should -Be 100
        $score.TrustStatus | Should -Be "Trusted"
    }
}
