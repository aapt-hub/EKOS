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

$moduleReporter = Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'audit/EKOS.GitHubIssueReporter.psm1'
$moduleOrchestrator = Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'audit/EKOS.AuditOrchestrator.psm1'

function Assert-True([bool]$cond, [string]$msg) {
    if (-not $cond) {
        throw "ASSERTION FAILED: $msg"
    }
}

function Invoke-TestCase([string]$name, [scriptblock]$test) {

    try {
        & $test
        Write-Output "PASS: $name"
        return $true
    } catch {
        Write-Output "FAIL: $name"
        Write-Output $_.Exception.Message
        return $false
    }
}

$failures = 0

$tests = @(
    @{ Name='Import both modules'; Test={
        Import-Module -Name $moduleReporter -Force | Out-Null
        Import-Module -Name $moduleOrchestrator -Force | Out-Null
    }},
    @{ Name='DryRun issue body is created'; Test={
        $root = (Get-Location).Path
        $res = New-EkosGitHubAuditIssue -AuditName 'T1' -Severity 'HIGH' -Summary 's' -FailedInvariant 'i' -RepositoryRoot $root -DryRun
        Assert-True ($res.Success -eq $true) 'Expected Success true in DryRun'
        Assert-True ($res.DryRun -eq $true) 'Expected DryRun true'
        Assert-True (Test-Path -LiteralPath $res.BodyPath) 'Expected body file exists'
    }},
    @{ Name='PASS audit creates no issue'; Test={
        $root = (Get-Location).Path
        $res = Invoke-EkosAuditWithIssueReporting -AuditName 'T2' -Severity 'HIGH' -AuditResult ([pscustomobject]@{ Success = $true }) -RepositoryRoot $root -DryRun
        Assert-True ($res.Success -eq $true) 'Expected Success true'
        Assert-True ($res.AuditPassed -eq $true) 'Expected AuditPassed true'
        Assert-True ($res.IssueCreated -eq $false) 'Expected no issue'
    }},
    @{ Name='FAIL audit creates issue body in DryRun'; Test={
        $root = (Get-Location).Path
        $res = Invoke-EkosAuditWithIssueReporting -AuditName 'T3' -Severity 'HIGH' -AuditResult ([pscustomobject]@{ Success = $false }) -FailedInvariant 'inv' -RepositoryRoot $root -DryRun
        Assert-True ($res.Success -eq $true) 'Expected Success true because DryRun should succeed'
        Assert-True ($res.IssueCreated -eq $false) 'Expected IssueCreated false in DryRun'
        # reporter should write body
        $safeAudit = ('T3' -replace '[^a-zA-Z0-9._-]','-')
        $bodyPath = Join-Path -Path $root -ChildPath "artifacts/audit/github-issue-body-$safeAudit.md"
        Assert-True (Test-Path -LiteralPath $bodyPath) 'Expected DryRun body file exists'
    }},
    @{ Name='Fingerprint is deterministic'; Test={
        $root = (Get-Location).Path
        $r1 = Invoke-EkosAuditWithIssueReporting -AuditName 'T4' -Severity 'LOW' -AuditResult ([pscustomobject]@{ Success = $false }) -FailedInvariant 'fi' -ModulePath 'mp' -RepositoryRoot $root -DryRun
        $r2 = Invoke-EkosAuditWithIssueReporting -AuditName 'T4' -Severity 'LOW' -AuditResult ([pscustomobject]@{ Success = $false }) -FailedInvariant 'fi' -ModulePath 'mp' -RepositoryRoot $root -DryRun
        Assert-True ($r1.Fingerprint -eq $r2.Fingerprint) 'Expected same fingerprint'
    }},
    @{ Name='Duplicate suppression works'; Test={
        $root = (Get-Location).Path
        $null = Invoke-EkosAuditWithIssueReporting -AuditName 'T5' -Severity 'LOW' -AuditResult ([pscustomobject]@{ Success = $false }) -FailedInvariant 'fi' -ModulePath 'mp' -RepositoryRoot $root -DryRun
        $r2 = Invoke-EkosAuditWithIssueReporting -AuditName 'T5' -Severity 'LOW' -AuditResult ([pscustomobject]@{ Success = $false }) -FailedInvariant 'fi' -ModulePath 'mp' -RepositoryRoot $root -DryRun
        Assert-True ($r2.DuplicateSuppressed -eq $true) 'Expected duplicate suppressed'
    }},
    @{ Name='Missing AuditScript and AuditResult returns structured failure'; Test={
        $root = (Get-Location).Path
        $r = Invoke-EkosAuditWithIssueReporting -AuditName 'T6' -Severity 'HIGH' -RepositoryRoot $root -DryRun
        Assert-True ($r.Success -eq $false) 'Expected Success false'
        Assert-True ($r.IssueCreated -eq $false) 'Expected IssueCreated false'
    }},
    @{ Name='Non-git RepositoryRoot returns structured failure from reporter'; Test={
        $tempRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('ekos-test-non-git-' + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
        $r = New-EkosGitHubAuditIssue -AuditName 'T7' -Severity 'HIGH' -Summary 's' -FailedInvariant 'i' -RepositoryRoot $tempRoot -DryRun
        Assert-True ($r.Success -eq $false) 'Expected Success false when not in git repo'
    }}
)

foreach ($t in $tests) {
    if (-not (Invoke-TestCase $t.Name $t.Test)) {

        $failures++
    }
}

if ($failures -gt 0) {
    Write-Output "TEST SUMMARY: $failures test(s) failed"
    exit 1
}

Write-Output 'TEST SUMMARY: all tests passed'
exit 0

