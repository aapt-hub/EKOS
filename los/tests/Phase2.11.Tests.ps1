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

Import-Module (Join-Path $script:trustRoot "LOS.TrustRecovery.psm1") -Force -Global

Describe "LOS Phase 2.11 Runtime Trust Recovery" {
    BeforeAll {
        function New-TestRecoveryRoot {
            $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("ekos-los-211-" + [guid]::NewGuid().ToString("N"))
            New-Item -ItemType Directory -Path (Join-Path $tempRoot "los\trust") -Force | Out-Null
            return $tempRoot
        }

        function New-TestRecoveryEvidence {
            param(
                [string] $CertificationStatus = "Passed",
                [string] $AttestationStatus = "Valid",
                [string] $PolicyStatus = "Compliant",
                [string] $IntegrityStatus = "Passed"
            )

            return [PSCustomObject][ordered]@{
                CertificationStatus = $CertificationStatus
                AttestationStatus   = $AttestationStatus
                PolicyStatus        = $PolicyStatus
                IntegrityStatus     = $IntegrityStatus
            }
        }

        function New-TestRecoveryRequest {
            param(
                [Parameter(Mandatory)]
                [string] $RootPath,

                [string] $TrustId = "trust-211",

                [string] $CurrentState = "Quarantined"
            )

            Request-LOSTrustRecovery `
                -RootPath $RootPath `
                -TrustId $TrustId `
                -Reason "Remediation complete" `
                -Evidence (New-TestRecoveryEvidence) `
                -RequestedBy "RuntimeOperator" `
                -CurrentState $CurrentState `
                -TimestampUtc "2026-06-24T00:00:00.0000000Z"
        }
    }

    It "creates recovery request for quarantined trust subject" {
        $tempRoot = New-TestRecoveryRoot
        try {
            $request = New-TestRecoveryRequest -RootPath $tempRoot -TrustId "trust-request"

            $request.CurrentState | Should -Be "RecoveryRequested"
            $request.PreviousState | Should -Be "Quarantined"
            $request.TrustId | Should -Be "trust-request"
            [string]::IsNullOrWhiteSpace($request.RecoveryRequestId) | Should -BeFalse
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "rejects missing TrustId" {
        $tempRoot = New-TestRecoveryRoot
        try {
            { Request-LOSTrustRecovery -RootPath $tempRoot -Reason "x" -Evidence (New-TestRecoveryEvidence) -RequestedBy "RuntimeOperator" } | Should -Throw
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "rejects missing Reason" {
        $tempRoot = New-TestRecoveryRoot
        try {
            { Request-LOSTrustRecovery -RootPath $tempRoot -TrustId "trust-missing-reason" -Evidence (New-TestRecoveryEvidence) -RequestedBy "RuntimeOperator" } | Should -Throw
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "rejects missing RequestedBy" {
        $tempRoot = New-TestRecoveryRoot
        try {
            { Request-LOSTrustRecovery -RootPath $tempRoot -TrustId "trust-missing-requestedby" -Reason "x" -Evidence (New-TestRecoveryEvidence) } | Should -Throw
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "rejects missing Evidence" {
        $tempRoot = New-TestRecoveryRoot
        try {
            { Request-LOSTrustRecovery -RootPath $tempRoot -TrustId "trust-missing-evidence" -Reason "x" -RequestedBy "RuntimeOperator" } | Should -Throw
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "rejects failing certification evidence" {
        $tempRoot = New-TestRecoveryRoot
        try {
            { Request-LOSTrustRecovery -RootPath $tempRoot -TrustId "trust-bad-cert" -Reason "x" -Evidence (New-TestRecoveryEvidence -CertificationStatus "Failed") -RequestedBy "RuntimeOperator" } | Should -Throw
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "rejects failing attestation evidence" {
        $tempRoot = New-TestRecoveryRoot
        try {
            { Request-LOSTrustRecovery -RootPath $tempRoot -TrustId "trust-bad-attestation" -Reason "x" -Evidence (New-TestRecoveryEvidence -AttestationStatus "Invalid") -RequestedBy "RuntimeOperator" } | Should -Throw
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "rejects failing policy evidence" {
        $tempRoot = New-TestRecoveryRoot
        try {
            { Request-LOSTrustRecovery -RootPath $tempRoot -TrustId "trust-bad-policy" -Reason "x" -Evidence (New-TestRecoveryEvidence -PolicyStatus "NonCompliant") -RequestedBy "RuntimeOperator" } | Should -Throw
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "rejects failing integrity evidence" {
        $tempRoot = New-TestRecoveryRoot
        try {
            { Request-LOSTrustRecovery -RootPath $tempRoot -TrustId "trust-bad-integrity" -Reason "x" -Evidence (New-TestRecoveryEvidence -IntegrityStatus "Failed") -RequestedBy "RuntimeOperator" } | Should -Throw
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "blocks duplicate active request" {
        $tempRoot = New-TestRecoveryRoot
        try {
            New-TestRecoveryRequest -RootPath $tempRoot -TrustId "trust-duplicate" | Out-Null

            { New-TestRecoveryRequest -RootPath $tempRoot -TrustId "trust-duplicate" } | Should -Throw
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "approves recovery request" {
        $tempRoot = New-TestRecoveryRoot
        try {
            $request = New-TestRecoveryRequest -RootPath $tempRoot -TrustId "trust-approve"
            $approval = Approve-LOSTrustRecovery -RootPath $tempRoot -RecoveryRequestId $request.RecoveryRequestId -ApprovedBy "TrustReviewer" -TimestampUtc "2026-06-24T00:01:00.0000000Z"

            $approval.Action | Should -Be "RevalidationRequired"
            $approval.ApprovedBy | Should -Be "TrustReviewer"
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "approval does not restore to Active" {
        $tempRoot = New-TestRecoveryRoot
        try {
            $request = New-TestRecoveryRequest -RootPath $tempRoot -TrustId "trust-approval-not-active"
            Approve-LOSTrustRecovery -RootPath $tempRoot -RecoveryRequestId $request.RecoveryRequestId -ApprovedBy "TrustReviewer" | Out-Null
            $history = @(Get-LOSTrustRecovery -RootPath $tempRoot -RecoveryRequestId $request.RecoveryRequestId)

            $history[-1].CurrentState | Should -Be "RevalidationRequired"
            @($history | Where-Object { $_.CurrentState -eq "Active" }).Count | Should -Be 0
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "approval moves to RevalidationRequired" {
        $tempRoot = New-TestRecoveryRoot
        try {
            $request = New-TestRecoveryRequest -RootPath $tempRoot -TrustId "trust-revalidation"
            $approval = Approve-LOSTrustRecovery -RootPath $tempRoot -RecoveryRequestId $request.RecoveryRequestId -ApprovedBy "TrustReviewer"

            $approval.CurrentState | Should -Be "RevalidationRequired"
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "denies recovery request" {
        $tempRoot = New-TestRecoveryRoot
        try {
            $request = New-TestRecoveryRequest -RootPath $tempRoot -TrustId "trust-deny"
            $denial = Deny-LOSTrustRecovery -RootPath $tempRoot -RecoveryRequestId $request.RecoveryRequestId -DeniedBy "TrustReviewer" -Reason "Insufficient remediation"

            $denial.CurrentState | Should -Be "RecoveryRejected"
            $denial.DeniedBy | Should -Be "TrustReviewer"
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "denied request cannot be approved afterward" {
        $tempRoot = New-TestRecoveryRoot
        try {
            $request = New-TestRecoveryRequest -RootPath $tempRoot -TrustId "trust-denied-then-approve"
            Deny-LOSTrustRecovery -RootPath $tempRoot -RecoveryRequestId $request.RecoveryRequestId -DeniedBy "TrustReviewer" | Out-Null

            { Approve-LOSTrustRecovery -RootPath $tempRoot -RecoveryRequestId $request.RecoveryRequestId -ApprovedBy "TrustReviewer" } | Should -Throw
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "approved request cannot be denied afterward" {
        $tempRoot = New-TestRecoveryRoot
        try {
            $request = New-TestRecoveryRequest -RootPath $tempRoot -TrustId "trust-approved-then-deny"
            Approve-LOSTrustRecovery -RootPath $tempRoot -RecoveryRequestId $request.RecoveryRequestId -ApprovedBy "TrustReviewer" | Out-Null

            { Deny-LOSTrustRecovery -RootPath $tempRoot -RecoveryRequestId $request.RecoveryRequestId -DeniedBy "TrustReviewer" } | Should -Throw
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "resolve requires approved or revalidation state" {
        $tempRoot = New-TestRecoveryRoot
        try {
            $request = New-TestRecoveryRequest -RootPath $tempRoot -TrustId "trust-resolve-unapproved"

            { Resolve-LOSTrustRecovery -RootPath $tempRoot -RecoveryRequestId $request.RecoveryRequestId -Evidence (New-TestRecoveryEvidence) -ReviewedBy "TrustAuthority" } | Should -Throw
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "resolve validates certification" {
        $tempRoot = New-TestRecoveryRoot
        try {
            $request = New-TestRecoveryRequest -RootPath $tempRoot -TrustId "trust-resolve-cert"
            Approve-LOSTrustRecovery -RootPath $tempRoot -RecoveryRequestId $request.RecoveryRequestId -ApprovedBy "TrustReviewer" | Out-Null

            { Resolve-LOSTrustRecovery -RootPath $tempRoot -RecoveryRequestId $request.RecoveryRequestId -Evidence (New-TestRecoveryEvidence -CertificationStatus "Failed") -ReviewedBy "TrustAuthority" } | Should -Throw
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "resolve validates attestation" {
        $tempRoot = New-TestRecoveryRoot
        try {
            $request = New-TestRecoveryRequest -RootPath $tempRoot -TrustId "trust-resolve-attestation"
            Approve-LOSTrustRecovery -RootPath $tempRoot -RecoveryRequestId $request.RecoveryRequestId -ApprovedBy "TrustReviewer" | Out-Null

            { Resolve-LOSTrustRecovery -RootPath $tempRoot -RecoveryRequestId $request.RecoveryRequestId -Evidence (New-TestRecoveryEvidence -AttestationStatus "Invalid") -ReviewedBy "TrustAuthority" } | Should -Throw
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "resolve validates policy" {
        $tempRoot = New-TestRecoveryRoot
        try {
            $request = New-TestRecoveryRequest -RootPath $tempRoot -TrustId "trust-resolve-policy"
            Approve-LOSTrustRecovery -RootPath $tempRoot -RecoveryRequestId $request.RecoveryRequestId -ApprovedBy "TrustReviewer" | Out-Null

            { Resolve-LOSTrustRecovery -RootPath $tempRoot -RecoveryRequestId $request.RecoveryRequestId -Evidence (New-TestRecoveryEvidence -PolicyStatus "NonCompliant") -ReviewedBy "TrustAuthority" } | Should -Throw
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "resolve validates integrity" {
        $tempRoot = New-TestRecoveryRoot
        try {
            $request = New-TestRecoveryRequest -RootPath $tempRoot -TrustId "trust-resolve-integrity"
            Approve-LOSTrustRecovery -RootPath $tempRoot -RecoveryRequestId $request.RecoveryRequestId -ApprovedBy "TrustReviewer" | Out-Null

            { Resolve-LOSTrustRecovery -RootPath $tempRoot -RecoveryRequestId $request.RecoveryRequestId -Evidence (New-TestRecoveryEvidence -IntegrityStatus "Failed") -ReviewedBy "TrustAuthority" } | Should -Throw
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "resolve produces staged validation states" {
        $tempRoot = New-TestRecoveryRoot
        try {
            $request = New-TestRecoveryRequest -RootPath $tempRoot -TrustId "trust-stages"
            Approve-LOSTrustRecovery -RootPath $tempRoot -RecoveryRequestId $request.RecoveryRequestId -ApprovedBy "TrustReviewer" | Out-Null
            Resolve-LOSTrustRecovery -RootPath $tempRoot -RecoveryRequestId $request.RecoveryRequestId -Evidence (New-TestRecoveryEvidence) -ReviewedBy "TrustAuthority" | Out-Null
            $states = @((Get-LOSTrustRecovery -RootPath $tempRoot -RecoveryRequestId $request.RecoveryRequestId) | Select-Object -ExpandProperty CurrentState)

            $states -contains "CertificationValidated" | Should -BeTrue
            $states -contains "AttestationValidated" | Should -BeTrue
            $states -contains "PolicyValidated" | Should -BeTrue
            $states -contains "TrustAuthorityReviewed" | Should -BeTrue
            $states -contains "Restored" | Should -BeTrue
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "resolve finally restores to Active" {
        $tempRoot = New-TestRecoveryRoot
        try {
            $request = New-TestRecoveryRequest -RootPath $tempRoot -TrustId "trust-active"
            Approve-LOSTrustRecovery -RootPath $tempRoot -RecoveryRequestId $request.RecoveryRequestId -ApprovedBy "TrustReviewer" | Out-Null
            $result = Resolve-LOSTrustRecovery -RootPath $tempRoot -RecoveryRequestId $request.RecoveryRequestId -Evidence (New-TestRecoveryEvidence) -ReviewedBy "TrustAuthority"

            $result.CurrentState | Should -Be "Active"
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "revoked trust subject cannot recover directly" {
        $tempRoot = New-TestRecoveryRoot
        try {
            { New-TestRecoveryRequest -RootPath $tempRoot -TrustId "trust-revoked" -CurrentState "Revoked" } | Should -Throw
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "denied trust subject can request recovery with valid new evidence" {
        $tempRoot = New-TestRecoveryRoot
        try {
            $request = New-TestRecoveryRequest -RootPath $tempRoot -TrustId "trust-denied-recovery" -CurrentState "Denied"

            $request.PreviousState | Should -Be "Denied"
            $request.CurrentState | Should -Be "RecoveryRequested"
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "ledger file is created" {
        $tempRoot = New-TestRecoveryRoot
        try {
            New-TestRecoveryRequest -RootPath $tempRoot -TrustId "trust-ledger-created" | Out-Null

            Test-Path -LiteralPath (Join-Path $tempRoot "los\trust\ledger\recovery-ledger.jsonl") | Should -BeTrue
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "ledger preserves multiple events" {
        $tempRoot = New-TestRecoveryRoot
        try {
            $request = New-TestRecoveryRequest -RootPath $tempRoot -TrustId "trust-ledger-events"
            Approve-LOSTrustRecovery -RootPath $tempRoot -RecoveryRequestId $request.RecoveryRequestId -ApprovedBy "TrustReviewer" | Out-Null
            Resolve-LOSTrustRecovery -RootPath $tempRoot -RecoveryRequestId $request.RecoveryRequestId -Evidence (New-TestRecoveryEvidence) -ReviewedBy "TrustAuthority" | Out-Null
            $lines = @(Get-Content -LiteralPath (Join-Path $tempRoot "los\trust\ledger\recovery-ledger.jsonl"))

            $lines.Count | Should -BeGreaterThan 7
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "ledger entries include EvidenceHash" {
        $tempRoot = New-TestRecoveryRoot
        try {
            New-TestRecoveryRequest -RootPath $tempRoot -TrustId "trust-evidence-hash" | Out-Null
            $entry = (Get-Content -LiteralPath (Join-Path $tempRoot "los\trust\ledger\recovery-ledger.jsonl") | Select-Object -First 1) | ConvertFrom-Json

            [string]::IsNullOrWhiteSpace($entry.EvidenceHash) | Should -BeFalse
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "ledger entries include DecisionHash" {
        $tempRoot = New-TestRecoveryRoot
        try {
            New-TestRecoveryRequest -RootPath $tempRoot -TrustId "trust-decision-hash" | Out-Null
            $entry = (Get-Content -LiteralPath (Join-Path $tempRoot "los\trust\ledger\recovery-ledger.jsonl") | Select-Object -First 1) | ConvertFrom-Json

            [string]::IsNullOrWhiteSpace($entry.DecisionHash) | Should -BeFalse
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "recovery history can be retrieved by TrustId" {
        $tempRoot = New-TestRecoveryRoot
        try {
            New-TestRecoveryRequest -RootPath $tempRoot -TrustId "trust-history-by-trust" | Out-Null
            $history = @(Get-LOSTrustRecovery -RootPath $tempRoot -TrustId "trust-history-by-trust")

            $history.Count | Should -Be 1
            $history[0].TrustId | Should -Be "trust-history-by-trust"
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "recovery history can be retrieved by RecoveryRequestId" {
        $tempRoot = New-TestRecoveryRoot
        try {
            $request = New-TestRecoveryRequest -RootPath $tempRoot -TrustId "trust-history-by-request"
            $history = @(Get-LOSTrustRecovery -RootPath $tempRoot -RecoveryRequestId $request.RecoveryRequestId)

            $history.Count | Should -Be 1
            $history[0].RecoveryRequestId | Should -Be $request.RecoveryRequestId
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "clear state resets recovery state" {
        $tempRoot = New-TestRecoveryRoot
        try {
            New-TestRecoveryRequest -RootPath $tempRoot -TrustId "trust-clear" | Out-Null
            Clear-LOSTrustRecoveryState -RootPath $tempRoot | Out-Null
            $state = Get-LOSTrustRecoveryState -RootPath $tempRoot

            $state.Requests.Count | Should -Be 0
            $state.Events.Count | Should -Be 0
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "repeated Clear state is safe" {
        $tempRoot = New-TestRecoveryRoot
        try {
            Clear-LOSTrustRecoveryState -RootPath $tempRoot | Out-Null
            Clear-LOSTrustRecoveryState -RootPath $tempRoot | Out-Null
            $state = Get-LOSTrustRecoveryState -RootPath $tempRoot

            $state.Events.Count | Should -Be 0
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "no direct Quarantined to Active transition exists" {
        $tempRoot = New-TestRecoveryRoot
        try {
            $request = New-TestRecoveryRequest -RootPath $tempRoot -TrustId "trust-no-direct-quarantine-active"
            Approve-LOSTrustRecovery -RootPath $tempRoot -RecoveryRequestId $request.RecoveryRequestId -ApprovedBy "TrustReviewer" | Out-Null
            Resolve-LOSTrustRecovery -RootPath $tempRoot -RecoveryRequestId $request.RecoveryRequestId -Evidence (New-TestRecoveryEvidence) -ReviewedBy "TrustAuthority" | Out-Null
            $direct = @((Get-LOSTrustRecovery -RootPath $tempRoot -RecoveryRequestId $request.RecoveryRequestId) | Where-Object { $_.PreviousState -eq "Quarantined" -and $_.CurrentState -eq "Active" })

            $direct.Count | Should -Be 0
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "no direct RecoveryApproved to Active transition exists" {
        $tempRoot = New-TestRecoveryRoot
        try {
            $request = New-TestRecoveryRequest -RootPath $tempRoot -TrustId "trust-no-direct-approval-active"
            Approve-LOSTrustRecovery -RootPath $tempRoot -RecoveryRequestId $request.RecoveryRequestId -ApprovedBy "TrustReviewer" | Out-Null
            Resolve-LOSTrustRecovery -RootPath $tempRoot -RecoveryRequestId $request.RecoveryRequestId -Evidence (New-TestRecoveryEvidence) -ReviewedBy "TrustAuthority" | Out-Null
            $direct = @((Get-LOSTrustRecovery -RootPath $tempRoot -RecoveryRequestId $request.RecoveryRequestId) | Where-Object { $_.PreviousState -eq "RecoveryApproved" -and $_.CurrentState -eq "Active" })

            $direct.Count | Should -Be 0
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }
}
