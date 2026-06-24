Set-StrictMode -Version Latest

function New-EkosGitHubAuditIssue {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $AuditName,

        [Parameter(Mandatory = $true)]
        [string] $Severity,

        [Parameter(Mandatory = $true)]
        [string] $Summary,

        [Parameter(Mandatory = $true)]
        [string] $FailedInvariant,

        [Parameter(Mandatory = $false)]
        [string] $ModulePath,

        [Parameter(Mandatory = $false)]
        [string] $Runtime,

        [Parameter(Mandatory = $false)]
        [string] $AuditArtifactPath,

        [Parameter(Mandatory = $false)]
        [string] $SuggestedFix,

        [Parameter(Mandatory = $false)]
        [string] $RepositoryRoot = (Get-Location).Path,

        [Parameter(Mandatory = $false)]
        [switch] $DryRun
    )

    begin {
        $ErrorActionPreference = 'Stop'
    }

    process {
        $tsUtc = (Get-Date).ToUniversalTime()

        $safeAuditName = ($AuditName -replace '[^a-zA-Z0-9._-]', '-')
        if ([string]::IsNullOrWhiteSpace($safeAuditName)) {
            $safeAuditName = 'audit'
        }

        $artifactsAuditDir = Join-Path -Path $RepositoryRoot -ChildPath 'artifacts/audit'
        $bodyPath = Join-Path -Path $artifactsAuditDir -ChildPath ("github-issue-body-$safeAuditName.md")

        $normalizedSeverityLower = ($Severity | ForEach-Object { $_.ToString().ToLowerInvariant() })

        $repoRootFull = $RepositoryRoot
        if (-not (Test-Path -LiteralPath $repoRootFull)) {
            $repoRootFull = (Get-Location).Path
        }

        $issueTitle = "EKOS Audit Failure: $AuditName [$Severity]"

        $gitDir = Join-Path -Path $repoRootFull -ChildPath '.git'
        $isGitRepo = Test-Path -LiteralPath $gitDir
        $ghAvailable = $false
        try {
            $ghAvailable = [bool](Get-Command 'gh' -ErrorAction SilentlyContinue)
        } catch {
            $ghAvailable = $false
        }

        $modulePathVal = $ModulePath
        $runtimeVal = $Runtime
        $auditArtifactPathVal = $AuditArtifactPath
        $suggestedFixVal = $SuggestedFix

        $missing = [System.Collections.Generic.List[string]]::new()
        if ([string]::IsNullOrWhiteSpace($AuditName)) { $missing.Add('AuditName') | Out-Null }
        if ([string]::IsNullOrWhiteSpace($Severity)) { $missing.Add('Severity') | Out-Null }
        if ([string]::IsNullOrWhiteSpace($Summary)) { $missing.Add('Summary') | Out-Null }
        if ([string]::IsNullOrWhiteSpace($FailedInvariant)) { $missing.Add('FailedInvariant') | Out-Null }

        $errorOut = ''
        $exitCode = $null
        $stdOut = ''
        $stdErr = ''

        # Ensure artifacts/audit exists
        try {
            if (-not (Test-Path -LiteralPath $artifactsAuditDir)) {
                New-Item -ItemType Directory -Path $artifactsAuditDir -Force | Out-Null
            }
        } catch {
            $errorOut = $_.Exception.Message
        }

        $body = @()
        $body += "Audit Name: $AuditName"
        $body += "Severity: $Severity"
        $body += "Summary: $Summary"
        $body += "Failed Invariant: $FailedInvariant"
        $body += "Module Path: $modulePathVal"
        $body += "Runtime: $runtimeVal"
        $body += "Audit Artifact Path: $auditArtifactPathVal"
        $body += "Suggested Fix: $suggestedFixVal"
        $body += "TimestampUtc: $tsUtc.ToString('o')"
        $body += "Repository Root: $repoRootFull"
        $bodyText = ($body -join "`n")

        try {
            Set-Content -Path $bodyPath -Value $bodyText -Encoding UTF8 -Force
        } catch {
            $errorOut = $_.Exception.Message
        }

        # Fail-closed behavior
        if (-not $isGitRepo) {
            return [pscustomobject]@{
                Success = $false
                IssueCreated = $false
                DryRun = [bool]$DryRun
                Title = $issueTitle
                BodyPath = $bodyPath
                ExitCode = $null
                StdOut = ''
                StdErr = $errorOut
                Error = 'Fail-closed: RepositoryRoot is not inside a git repo (missing .git).' 
            }
        }

        if (-not $ghAvailable) {
            return [pscustomobject]@{
                Success = $false
                IssueCreated = $false
                DryRun = [bool]$DryRun
                Title = $issueTitle
                BodyPath = $bodyPath
                ExitCode = $null
                StdOut = ''
                StdErr = $errorOut
                Error = 'Fail-closed: gh CLI is unavailable.'
            }
        }

        if ($DryRun) {
            return [pscustomobject]@{
                Success = $true
                IssueCreated = $false
                DryRun = $true
                Title = $issueTitle
                BodyPath = $bodyPath
                ExitCode = $null
                StdOut = ''
                StdErr = ''
                Error = ''
            }
        }

        # Create issue
        try {
            $labels = @('audit','bug','ekos',"severity:$normalizedSeverityLower")
$ghArgs = @('issue','create','--title',$issueTitle,'--body-file',$bodyPath)
            foreach ($l in $labels) {
                $ghArgs += @('--label',$l)
            }


$pInfo = Start-Process -FilePath 'gh' -ArgumentList $ghArgs -NoNewWindow -PassThru -Wait
            $exitCode = $null
            try {
                $exitCode = $pInfo.ExitCode
            } catch {
                $exitCode = $null
            }


            return [pscustomobject]@{
                Success = ($exitCode -eq 0)
                IssueCreated = ($exitCode -eq 0)
                DryRun = $false
                Title = $issueTitle
                BodyPath = $bodyPath
                ExitCode = $exitCode
                StdOut = $stdOut
                StdErr = $stdErr
                Error = ''
            }
        } catch {
            $errorOut = $_.Exception.Message
            return [pscustomobject]@{
                Success = $false
                IssueCreated = $false
                DryRun = $false
                Title = $issueTitle
                BodyPath = $bodyPath
                ExitCode = $exitCode
                StdOut = $stdOut
                StdErr = $stdErr
                Error = $errorOut
            }
        }
    }
}

Export-ModuleMember -Function New-EkosGitHubAuditIssue

