Set-StrictMode -Version Latest

function Get-LOSTrustPropertyValue {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object] $InputObject,

        [Parameter(Mandatory)]
        [string] $Name
    )

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        if ($InputObject.Contains($Name)) {
            return $InputObject[$Name]
        }
        return $null
    }

    if ($InputObject.PSObject.Properties.Name -contains $Name) {
        return $InputObject.$Name
    }

    return $null
}

function Test-LOSTrustPositiveEvidence {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object] $InputObject
    )

    if ($null -eq $InputObject) {
        return $false
    }

    $success = Get-LOSTrustPropertyValue -InputObject $InputObject -Name "Success"
    if ($success -eq $true) {
        return $true
    }

    $decision = Get-LOSTrustPropertyValue -InputObject $InputObject -Name "Decision"
    if ($decision -eq "ALLOW") {
        return $true
    }

    $status = Get-LOSTrustPropertyValue -InputObject $InputObject -Name "Status"
    if ($status -in @("PASS", "Passed", "Healthy", "Trusted", "TRUSTED")) {
        return $true
    }

    $certificationStatus = Get-LOSTrustPropertyValue -InputObject $InputObject -Name "CertificationStatus"
    if ($certificationStatus -eq "PASS") {
        return $true
    }

    $trustStatus = Get-LOSTrustPropertyValue -InputObject $InputObject -Name "TrustStatus"
    if ($trustStatus -in @("Trusted", "TRUSTED")) {
        return $true
    }

    $runtimeHealth = Get-LOSTrustPropertyValue -InputObject $InputObject -Name "RuntimeHealth"
    if ($runtimeHealth -eq "Healthy") {
        return $true
    }

    return $false
}

function Get-LOSTrustComponentScore {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object] $InputObject,

        [Parameter(Mandatory)]
        [int] $Weight
    )

    if (Test-LOSTrustPositiveEvidence -InputObject $InputObject) {
        return $Weight
    }

    $score = Get-LOSTrustPropertyValue -InputObject $InputObject -Name "Score"
    if ($null -ne $score) {
        $numeric = [double] $score
        if ($numeric -lt 0) { $numeric = 0 }
        if ($numeric -gt 100) { $numeric = 100 }
        return [int] [System.Math]::Round(($numeric / 100) * $Weight)
    }

    $runtimeHealth = Get-LOSTrustPropertyValue -InputObject $InputObject -Name "RuntimeHealth"
    if ($runtimeHealth -eq "Warning") {
        return [int] [System.Math]::Round($Weight * 0.75)
    }
    if ($runtimeHealth -eq "Degraded") {
        return [int] [System.Math]::Round($Weight * 0.5)
    }

    return 0
}

function Get-LOSTrustStatusFromScore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int] $Score
    )

    if ($Score -ge 90) { return "Trusted" }
    if ($Score -ge 75) { return "Warning" }
    if ($Score -ge 50) { return "Degraded" }
    return "Untrusted"
}

function Get-LOSTrustScore {
    [CmdletBinding()]
    param(
        [string] $TrustId = "",

        [AllowNull()]
        [object] $Governance,

        [AllowNull()]
        [object] $Certification,

        [AllowNull()]
        [object] $RuntimeHealth,

        [AllowNull()]
        [object] $HistoricalTrust,

        [AllowNull()]
        [object] $Evidence,

        [string] $TimestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    )

    if ($null -ne $Evidence) {
        if ([string]::IsNullOrWhiteSpace($TrustId)) {
            $evidenceTrustId = Get-LOSTrustPropertyValue -InputObject $Evidence -Name "TrustId"
            if (-not [string]::IsNullOrWhiteSpace([string] $evidenceTrustId)) {
                $TrustId = [string] $evidenceTrustId
            }
        }

        if ($null -eq $Governance) {
            $Governance = Get-LOSTrustPropertyValue -InputObject $Evidence -Name "Governance"
        }
        if ($null -eq $Certification) {
            $Certification = Get-LOSTrustPropertyValue -InputObject $Evidence -Name "Certification"
        }
        if ($null -eq $RuntimeHealth) {
            $RuntimeHealth = Get-LOSTrustPropertyValue -InputObject $Evidence -Name "RuntimeHealth"
        }
        if ($null -eq $HistoricalTrust) {
            $HistoricalTrust = Get-LOSTrustPropertyValue -InputObject $Evidence -Name "HistoricalTrust"
        }
    }

    if ([string]::IsNullOrWhiteSpace($TrustId)) {
        $TrustId = "unknown"
    }

    $governanceScore = Get-LOSTrustComponentScore -InputObject $Governance -Weight 40
    $certificationScore = Get-LOSTrustComponentScore -InputObject $Certification -Weight 25
    $runtimeScore = Get-LOSTrustComponentScore -InputObject $RuntimeHealth -Weight 20
    $historyScore = Get-LOSTrustComponentScore -InputObject $HistoricalTrust -Weight 15
    $score = $governanceScore + $certificationScore + $runtimeScore + $historyScore

    return [PSCustomObject][ordered]@{
        TrustId      = $TrustId
        Score        = $score
        TrustStatus  = Get-LOSTrustStatusFromScore -Score $score
        TimestampUtc = $TimestampUtc
        Components   = [PSCustomObject][ordered]@{
            Governance      = $governanceScore
            Certification   = $certificationScore
            RuntimeHealth   = $runtimeScore
            HistoricalTrust = $historyScore
        }
        Evidence     = [PSCustomObject][ordered]@{
            Governance      = $Governance
            Certification   = $Certification
            RuntimeHealth   = $RuntimeHealth
            HistoricalTrust = $HistoricalTrust
        }
    }
}

function Update-LOSTrustScore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RootPath,

        [string] $TrustId = "",

        [AllowNull()]
        [object] $Governance,

        [AllowNull()]
        [object] $Certification,

        [AllowNull()]
        [object] $RuntimeHealth,

        [AllowNull()]
        [object] $HistoricalTrust,

        [AllowNull()]
        [object] $Evidence,

        [string] $TimestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    )

    $score = Get-LOSTrustScore -TrustId $TrustId -Governance $Governance -Certification $Certification -RuntimeHealth $RuntimeHealth -HistoricalTrust $HistoricalTrust -Evidence $Evidence -TimestampUtc $TimestampUtc
    $monitoringDir = Join-Path $RootPath "los\monitoring"
    if (-not (Test-Path -LiteralPath $monitoringDir)) {
        New-Item -ItemType Directory -Path $monitoringDir | Out-Null
    }

    $scoreFile = Join-Path $monitoringDir "trust-scores.jsonl"
    Add-Content -LiteralPath $scoreFile -Value ($score | ConvertTo-Json -Depth 20 -Compress)

    return $score
}

Export-ModuleMember -Function Get-LOSTrustScore, Update-LOSTrustScore
