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

# Ensure dependency is available when module imported directly.
$script:ModuleRoot = Split-Path -Parent $PSScriptRoot
$script:ReporterPath = Join-Path -Path $script:ModuleRoot -ChildPath 'audit/EKOS.GitHubIssueReporter.psm1'
if (Test-Path -LiteralPath $script:ReporterPath) {
    Import-Module -Name $script:ReporterPath -Force -ErrorAction SilentlyContinue | Out-Null
}

function Invoke-EkosAuditWithIssueReporting {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $AuditName,

        [Parameter(Mandatory = $false)]
        [string] $Severity = 'HIGH',

        [Parameter(Mandatory = $false)]
        [scriptblock] $AuditScript,

        [Parameter(Mandatory = $false)]
        [object] $AuditResult,

        [Parameter(Mandatory = $false)]
        [string] $FailedInvariant,

        [Parameter(Mandatory = $false)]
        [string] $ModulePath,

        [Parameter(Mandatory = $false)]
        [string] $Runtime,

        [Parameter(Mandatory = $false)]
        [string] $SuggestedFix,

        [Parameter(Mandatory = $false)]
        [string] $RepositoryRoot = (Get-Location).Path,

        [Parameter(Mandatory = $false)]
        [switch] $DryRun
    )

    begin {
        $ErrorActionPreference = 'Stop'

        function Get-PassState($r) {
            if ($null -eq $r) { return $false }
            try {
                if ($r.PSObject.Properties['Success'] -and $r.Success -eq $true) { return $true }
            } catch {}
            try {
                if ($r.PSObject.Properties['Passed'] -and $r.Passed -eq $true) { return $true }
            } catch {}
            try {
                if ($r.PSObject.Properties['Status'] -and $r.Status -eq 'PASS') { return $true }
            } catch {}
            try {
                if ($r.PSObject.Properties['Result'] -and $r.Result -eq 'PASS') { return $true }
            } catch {}
            return $false
        }
    }

    process {
        if ($null -eq $AuditScript -and $null -eq $AuditResult) {
            return [pscustomobject]@{
                Success = $false
                AuditPassed = $false
                IssueCreated = $false
                DuplicateSuppressed = $false
                Fingerprint = $null
                IssueResult = $null
                Error = 'Structured failure: neither AuditScript nor AuditResult was supplied.'
            }
        }

        $issueCachePath = Join-Path -Path $RepositoryRoot -ChildPath 'artifacts/audit/issue-cache.json'
        $cacheDir = Split-Path -Parent $issueCachePath
        try {
            if (-not (Test-Path -LiteralPath $cacheDir)) {
                New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
            }
        } catch {
            # cache creation errors are handled via fail-closed on reporter.
        }

        $auditEval = $null
        $issueError = ''

        try {
            if ($null -ne $AuditScript) {
                $auditEval = & $AuditScript
            } else {
                $auditEval = $AuditResult
            }
        } catch {
            $auditEval = $null
            $issueError = $_.Exception.Message
        }

        $isPassed = Get-PassState $auditEval

        if ($isPassed) {
            return [pscustomobject]@{
                Success = $true
                AuditPassed = $true
                IssueCreated = $false
                DuplicateSuppressed = $false
                Fingerprint = $null
                IssueResult = $null
                Error = ''
            }
        }

        $fingerprintInput = ($AuditName + '|' + $Severity + '|' + ($FailedInvariant ?? '') + '|' + ($ModulePath ?? ''))
        $sha = [System.Security.Cryptography.SHA256]::Create()
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($fingerprintInput)
        $hash = ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join ''

        $cache = @{}
        try {
            if (Test-Path -LiteralPath $issueCachePath) {
                $raw = Get-Content -LiteralPath $issueCachePath -Raw -ErrorAction Stop
                if (-not [string]::IsNullOrWhiteSpace($raw)) {
                    $cache = ConvertFrom-Json -InputObject $raw -ErrorAction Stop
                }
            }
        } catch {
            $cache = @{}
        }

        $existing = $false
        try {
            if ($cache -is [System.Collections.IDictionary]) {
                $existing = $cache.Contains($hash)
            } else {
                $existing = ($cache.PSObject.Properties.Name -contains $hash)
            }
        } catch {}

        if ($existing) {
            return [pscustomobject]@{
                Success = $true
                AuditPassed = $false
                IssueCreated = $false
                DuplicateSuppressed = $true
                Fingerprint = $hash
                IssueResult = $null
                Error = ''
            }
        }

        # Not cached => report
        $summary = $auditEval
        if ($null -eq $summary) { $summary = 'Audit failed.' }

        $issueResult = $null
        try {
            $issueResult = New-EkosGitHubAuditIssue -AuditName $AuditName -Severity $Severity -Summary $summary -FailedInvariant ($FailedInvariant ?? '') -ModulePath $ModulePath -Runtime $Runtime -AuditArtifactPath $issueCachePath -SuggestedFix $SuggestedFix -RepositoryRoot $RepositoryRoot -DryRun:$DryRun
        } catch {
            $issueResult = $null
        }

        if ($null -ne $issueResult -and $issueResult.Success -eq $true) {
            # update cache
            try {
                $cacheObj = $cache
                if ($cacheObj -is [System.Collections.IDictionary]) {
                    $cacheObj[$hash] = $true
                } else {
                    # convert to dictionary
                    $dict = @{}
                    foreach ($p in $cacheObj.PSObject.Properties) { $dict[$p.Name] = $p.Value }
                    $dict[$hash] = $true
                    $cacheObj = $dict
                }
                $cacheObjJson = ($cacheObj | ConvertTo-Json -Depth 5 -Compress)
                Set-Content -LiteralPath $issueCachePath -Value $cacheObjJson -Encoding UTF8 -Force
            } catch {}
        }

        return [pscustomobject]@{
            Success = ($null -ne $issueResult -and $issueResult.Success -eq $true)
            AuditPassed = $false
            IssueCreated = ($null -ne $issueResult -and $issueResult.IssueCreated -eq $true)
            DuplicateSuppressed = $false
            Fingerprint = $hash
            IssueResult = $issueResult
            Error = ($null -ne $issueResult ? $issueResult.Error : $issueError)
        }
    }
}

Export-ModuleMember -Function Invoke-EkosAuditWithIssueReporting

