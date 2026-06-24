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
$script:repoRoot = (Resolve-Path (Join-Path $script:here "..\.." )).Path
$script:trustRoot = Join-Path $script:repoRoot "los\trust"
$script:policyRoot = Join-Path $script:repoRoot "los\policies"

Import-Module (Join-Path $script:trustRoot "LOS.PolicyRegistry.psm1") -Force -Global
Import-Module (Join-Path $script:trustRoot "LOS.TrustPolicy.psm1") -Force -Global
Import-Module (Join-Path $script:trustRoot "LOS.PolicyDecision.psm1") -Force -Global

Describe "LOS Phase 2.12 Runtime Trust Policy Engine" {
    BeforeAll {
        Clear-LOSPolicyDecisionState | Out-Null
        Clear-LOSTrustPolicyState | Out-Null
    }

    It "policy registration and retrieval" {
        $policyJson = @{
            PolicyId = "test-policy-001"
            Name = "Test"
            Version = "1.0.0"
            Enabled = $true
            Scope = @{ SubjectType = "RuntimeAuthorized" }
            Conditions = @(@{ Field = "RuntimeAuthorized"; Operator = "Equals"; Value = $true })
            Actions = @(@{ Outcome = "Allow"; Severity = "Info"; Reason = "Ok" })
            Severity = "Info"
            CreatedBy = "unit"
            CreatedUtc = "2026-06-24T00:00:00.0000000Z"
        } | ConvertTo-Json -Depth 10

        $policyObj = $policyJson | ConvertFrom-Json
        $registered = Register-LOSPolicy -Policy $policyObj -RootPath $script:repoRoot
        $fromReg = Get-LOSPolicy -PolicyId "test-policy-001"

        $registered.PolicyId | Should -Be "test-policy-001"
        $fromReg.PolicyId | Should -Be "test-policy-001"
    }

    It "invalid policy rejection (missing required fields)" {
        $bad = [PSCustomObject]@{ PolicyId = "bad-1" }
        { Register-LOSPolicy -Policy $bad -RootPath $script:repoRoot } | Should -Throw
    }

    It "trust score policy evaluation (quarantine)" {
        Clear-LOSTrustPolicyState | Out-Null
        $result = Invoke-LOSTrustPolicy -SubjectId "runtime-qs" -Evidence ([PSCustomObject][ordered]@{
            SubjectId = "runtime-qs"
            TrustScore = 39
            CertificationStatus = "PASS"
            CertificationExpired = $false
            RecoveryAttempts = 0
            DriftSeverity = 0
            RuntimeAuthorized = $true
            TrustStatus = "Trusted"
        }) -TimestampUtc "2026-06-24T00:00:00.0000000Z"

        $result.Decision.Result | Should -Be "Quarantine"
        $result.Decision.Severity | Should -Be "Warning"
    }

    It "certification policy evaluation (allow when not expired)" {
        Clear-LOSTrustPolicyState | Out-Null
        $result = Invoke-LOSTrustPolicy -SubjectId "runtime-cert-allow" -Evidence ([PSCustomObject][ordered]@{
            SubjectId = "runtime-cert-allow"
            TrustScore = 100
            CertificationStatus = "PASS"
            CertificationExpired = $false
            RecoveryAttempts = 0
            DriftSeverity = 0
            RuntimeAuthorized = $true
            TrustStatus = "Trusted"
        }) -TimestampUtc "2026-06-24T00:00:00.0000000Z"

        $result.Decision.Result | Should -Be "Allow"
    }

    It "recovery attempts policy evaluation (recover)" {
        Clear-LOSTrustPolicyState | Out-Null
        $result = Invoke-LOSTrustPolicy -SubjectId "runtime-recover" -Evidence ([PSCustomObject][ordered]@{
            SubjectId = "runtime-recover"
            TrustScore = 100
            CertificationStatus = "PASS"
            CertificationExpired = $false
            RecoveryAttempts = 2
            DriftSeverity = 0
            RuntimeAuthorized = $false
            TrustStatus = "Untrusted"
        }) -TimestampUtc "2026-06-24T00:00:00.0000000Z"

        $result.Decision.Result | Should -Be "Recover"
    }

    It "drift policy evaluation (quarantine)" {
        Clear-LOSTrustPolicyState | Out-Null
        $result = Invoke-LOSTrustPolicy -SubjectId "runtime-drift" -Evidence ([PSCustomObject][ordered]@{
            SubjectId = "runtime-drift"
            TrustScore = 100
            CertificationStatus = "PASS"
            CertificationExpired = $false
            RecoveryAttempts = 0
            DriftSeverity = 8
            RuntimeAuthorized = $true
            TrustStatus = "Trusted"
        }) -TimestampUtc "2026-06-24T00:00:00.0000000Z"

        $result.Decision.Result | Should -Be "Quarantine"
        $result.Decision.Severity | Should -Be "Critical"
    }

    It "unauthorized runtime policy evaluation (fail-closed deny)" {
        Clear-LOSTrustPolicyState | Out-Null
        $result = Invoke-LOSTrustPolicy -SubjectId "runtime-unauth" -Evidence ([PSCustomObject][ordered]@{
            SubjectId = "runtime-unauth"
            TrustScore = 10
            CertificationStatus = "PASS"
            CertificationExpired = $false
            RecoveryAttempts = 0
            DriftSeverity = 0
            RuntimeAuthorized = $false
            TrustStatus = "Untrusted"
        }) -TimestampUtc "2026-06-24T00:00:00.0000000Z"

        $result.Decision.Result | Should -Be "Deny"
    }

    It "disabled policy ignored" {
        $disabled = [PSCustomObject][ordered]@{
            PolicyId = "disabled-001"
            Name = "Disabled"
            Version = "1.0.0"
            Enabled = $false
            Scope = @{ SubjectType = "RuntimeAuthorized" }
            Conditions = @(@{ Field = "RuntimeAuthorized"; Operator = "Equals"; Value = $true })
            Actions = @(@{ Outcome = "Allow"; Severity = "Info"; Reason = "Disabled" })
            Severity = "Info"
            CreatedBy = "unit"
            CreatedUtc = "2026-06-24T00:00:00.0000000Z"
        }
        Register-LOSPolicy -Policy $disabled -RootPath $script:repoRoot | Out-Null

        $result = Invoke-LOSTrustPolicy -SubjectId "runtime-dis" -Evidence ([PSCustomObject][ordered]@{
            SubjectId = "runtime-dis"
            TrustScore = 100
            CertificationStatus = "PASS"
            CertificationExpired = $false
            RecoveryAttempts = 0
            DriftSeverity = 0
            RuntimeAuthorized = $true
            TrustStatus = "Trusted"
        }) -TimestampUtc "2026-06-24T00:00:00.0000000Z"

        $result.Decision.Result | Should -Be "Allow"
    }

    It "missing evidence for matched condition fails closed" {
        $result = Invoke-LOSTrustPolicy -SubjectId "runtime-missing" -Evidence ([PSCustomObject][ordered]@{
            SubjectId = "runtime-missing"
            TrustScore = 10
            RuntimeAuthorized = $true
        }) -TimestampUtc "2026-06-24T00:00:00.0000000Z"

        $result.Decision.Result | Should -Be "Deny"
    }

    It "deterministic EvidenceHash" {
        Clear-LOSPolicyDecisionState | Out-Null
        $evidence = [PSCustomObject][ordered]@{ A = 1; B = @(2,3) }
        $d1 = New-LOSPolicyDecision -DecisionId "d1" -PolicyId "p" -SubjectId "s" -Result "Allow" -Actions @(@{Outcome="Allow"}) -Severity "Info" -TimestampUtc "2026-06-24T00:00:00.0000000Z" -Evidence $evidence
        Clear-LOSPolicyDecisionState | Out-Null
        $d2 = New-LOSPolicyDecision -DecisionId "d2" -PolicyId "p" -SubjectId "s" -Result "Allow" -Actions @(@{Outcome="Allow"}) -Severity "Info" -TimestampUtc "2026-06-24T00:00:00.0000000Z" -Evidence $evidence
        $d1.EvidenceHash | Should -Be $d2.EvidenceHash
    }

    It "Clear state behavior" {
        Clear-LOSTrustPolicyState | Out-Null
        $state = Get-LOSTrustPolicyState
        $state.LastEvaluation | Should -BeNullOrEmpty
        Clear-LOSPolicyDecisionState | Out-Null
        (Get-LOSPolicyDecisionState).Decisions.Count | Should -Be 0
    }

    It "compatibility with existing trust modules" {
        Get-Command Invoke-LOSTrustEnforcement -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        Get-Command Request-LOSTrustRecovery -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }
}

