Set-StrictMode -Version Latest

$script:here = $PSScriptRoot
$script:repoRoot = (Resolve-Path (Join-Path $script:here "..\..")).Path
$script:trustRoot = Join-Path $script:repoRoot "los\trust"

Import-Module (Join-Path $script:trustRoot "LOS.TrustEvidence.psm1") -Force -Global
Import-Module (Join-Path $script:trustRoot "LOS.TrustDecision.psm1") -Force -Global
Import-Module (Join-Path $script:trustRoot "LOS.TrustLedger.psm1") -Force -Global
Import-Module (Join-Path $script:trustRoot "LOS.TrustReport.psm1") -Force -Global
Import-Module (Join-Path $script:trustRoot "LOS.RuntimeTrustAuthority.psm1") -Force -Global

Describe "LOS Phase 2.8 Runtime Trust Authority" {
    BeforeAll {
        function New-TestTrustRoot {
            $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("ekos-los-28-" + [guid]::NewGuid().ToString("N"))
            New-Item -ItemType Directory -Path (Join-Path $tempRoot "los\trust-data") -Force | Out-Null
            return $tempRoot
        }

        function New-ReferenceTrustEvidence {
            param(
                [string] $RuntimeHash = "runtime-hash-1",
                [string] $CertificationStatus = "PASS",
                [string[]] $Capabilities = @("execute", "deterministic")
            )

            New-LOSTrustEvidence `
                -TrustEvidenceId "trust-1" `
                -RuntimeId "PS7" `
                -RuntimeVersion "7.x" `
                -RuntimeHash $RuntimeHash `
                -CertificationId "cert-1" `
                -CertificationStatus $CertificationStatus `
                -EvidenceHash "evidence-hash-1" `
                -Capabilities $Capabilities `
                -TimestampUtc "2026-06-23T00:00:00.0000000Z" `
                -RepoRoot $script:repoRoot
        }
    }

    It "generates deterministic trust evidence hashes" {
        $left = New-ReferenceTrustEvidence -Capabilities @("deterministic", "execute")
        $right = New-ReferenceTrustEvidence -Capabilities @("execute", "deterministic")

        $left.TrustEvidenceHash | Should -Be $right.TrustEvidenceHash
        $left.TrustEvidenceHash.Length | Should -Be 64
    }

    It "allows trusted runtime evidence" {
        $evidence = New-ReferenceTrustEvidence
        $decision = New-LOSTrustDecision -TrustEvidence $evidence -RequiredCapabilities @("execute") -AllowedRuntimeHashes @("runtime-hash-1")

        $decision.Success | Should -BeTrue
        $decision.Decision | Should -Be "ALLOW"
        $decision.TrustStatus | Should -Be "TRUSTED"
    }

    It "fails closed when trust evidence is missing" {
        $decision = New-LOSTrustDecision -TrustEvidence $null

        $decision.Success | Should -BeFalse
        $decision.Decision | Should -Be "DENY"
        $decision.Reason | Should -Be "TrustEvidenceMissing"
    }

    It "fails closed when certification did not pass" {
        $evidence = New-ReferenceTrustEvidence -CertificationStatus "FAIL"
        $decision = New-LOSTrustDecision -TrustEvidence $evidence

        $decision.Success | Should -BeFalse
        $decision.Decision | Should -Be "DENY"
        $decision.Reason | Should -Be "CertificationNotTrusted"
    }

    It "fails closed when required capabilities are absent" {
        $evidence = New-ReferenceTrustEvidence -Capabilities @("deterministic")
        $decision = New-LOSTrustDecision -TrustEvidence $evidence -RequiredCapabilities @("execute")

        $decision.Success | Should -BeFalse
        $decision.Decision | Should -Be "DENY"
        $decision.Reason | Should -Be "CapabilityNotTrusted"
    }

    It "fails closed when runtime hash is not trusted" {
        $evidence = New-ReferenceTrustEvidence -RuntimeHash "runtime-hash-2"
        $decision = New-LOSTrustDecision -TrustEvidence $evidence -AllowedRuntimeHashes @("runtime-hash-1")

        $decision.Success | Should -BeFalse
        $decision.Decision | Should -Be "DENY"
        $decision.Reason | Should -Be "RuntimeHashNotTrusted"
    }

    It "allows authority execution and writes trust artifacts" {
        $tempRoot = New-TestTrustRoot
        try {
            $evidence = New-ReferenceTrustEvidence
            $governance = [PSCustomObject][ordered]@{ Decision = "ALLOW" }
            $certification = [PSCustomObject][ordered]@{ CertificationStatus = "PASS" }

            $result = Invoke-LOSRuntimeTrustAuthority -RootPath $tempRoot -GovernanceResult $governance -CertificationResult $certification -TrustEvidence $evidence -RequiredCapabilities @("execute") -AllowedRuntimeHashes @("runtime-hash-1") -TimestampUtc "2026-06-23T00:00:00.0000000Z"

            $result.Success | Should -BeTrue
            $result.Decision | Should -Be "ALLOW"
            (Test-Path -LiteralPath $result.LedgerWrite.LedgerFile) | Should -BeTrue
            (Test-Path -LiteralPath $result.ReportPath) | Should -BeTrue
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "authority denies when governance is not allowed" {
        $tempRoot = New-TestTrustRoot
        try {
            $evidence = New-ReferenceTrustEvidence
            $governance = [PSCustomObject][ordered]@{ Decision = "DENY" }
            $certification = [PSCustomObject][ordered]@{ CertificationStatus = "PASS" }

            $result = Invoke-LOSRuntimeTrustAuthority -RootPath $tempRoot -GovernanceResult $governance -CertificationResult $certification -TrustEvidence $evidence -TimestampUtc "2026-06-23T00:00:00.0000000Z"

            $result.Success | Should -BeFalse
            $result.Decision | Should -Be "DENY"
            $result.Reason | Should -Be "GovernanceNotAllowed"
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "appends and reads trust ledger entries" {
        $tempRoot = New-TestTrustRoot
        try {
            $entry = [PSCustomObject][ordered]@{
                TimestampUtc      = "2026-06-23T00:00:00.0000000Z"
                Decision          = "ALLOW"
                TrustStatus       = "TRUSTED"
                Reason            = "TrustedRuntime"
                TrustEvidenceHash = "hash-1"
            }

            Write-LOSTrustLedger -RootPath $tempRoot -Entry $entry | Out-Null
            Write-LOSTrustLedger -RootPath $tempRoot -Entry $entry | Out-Null
            $rows = @(Read-LOSTrustLedger -RootPath $tempRoot)

            $rows.Count | Should -Be 2
            $rows[0].TrustEvidenceHash | Should -Be "hash-1"
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "emits structured trust reports" {
        $evidence = New-ReferenceTrustEvidence
        $decision = New-LOSTrustDecision -TrustEvidence $evidence
        $json = New-LOSTrustReport -TrustDecision $decision -TrustEvidence $evidence -GeneratedUtc "2026-06-23T00:00:00.0000000Z"
        $report = $json | ConvertFrom-Json

        $report.Decision | Should -Be "ALLOW"
        $report.TrustStatus | Should -Be "TRUSTED"
        $report.TrustEvidenceHash | Should -Be $evidence.TrustEvidenceHash
    }
}
