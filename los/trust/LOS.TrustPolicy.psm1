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

<#
.SYNOPSIS
LOS Trust Policy Engine.

.DESCRIPTION
Deterministic policy evaluator for LOS-TRUST-005.

Evaluates subject/evidence against applicable JSON runtime trust policies.
Fail-closed on invalid evidence or ambiguous policy evaluation.
#>
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot "LOS.PolicyRegistry.psm1") -Force -Global
Import-Module (Join-Path $PSScriptRoot "LOS.PolicyDecision.psm1") -Force -Global
Import-Module (Join-Path $PSScriptRoot "LOS.RuntimeTrustEnforcement.psm1") -Force -Global
Import-Module (Join-Path $PSScriptRoot "LOS.TrustRecovery.psm1") -Force -Global

$script:TrustPolicyState = [ordered]@{
    LastEvaluation = $null
}

function Clear-LOSTrustPolicyState {
    [CmdletBinding()]
    param()

    $script:TrustPolicyState = [ordered]@{ LastEvaluation = $null }
    return [PSCustomObject][ordered]@{ Success = $true; Cleared = $true }
}

function Get-LOSTrustPolicyState {
    [CmdletBinding()]
    param()

    return $script:TrustPolicyState
}

function Test-LOSTrustPolicy {
    [CmdletBinding()]
    param()

    # Minimal smoke-test.
    $policies = Get-LOSPolicies
    return [PSCustomObject][ordered]@{ Success = ($null -ne $policies); PolicyCount = @($policies).Count }
}

function Get-LOSFieldValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Evidence,
        [Parameter(Mandatory)]
        [string] $Name
    )

    if ($Evidence -is [System.Collections.IDictionary]) {
        if ($Evidence.Contains($Name)) { return $Evidence[$Name] }
        return $null
    }

    if ($null -ne $Evidence -and $Evidence.PSObject.Properties.Name -contains $Name) {
        return $Evidence.$Name
    }

    return $null
}

function Convert-LOSNumber {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object] $Value
    )

    if ($Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [decimal]) {
        return [double]$Value
    }

    if ($null -eq $Value) { return $null }

    $parsed = 0
    $ok = [double]::TryParse([string]$Value, [ref] $parsed)
    if (-not $ok) { return $null }
    return $parsed
}

function Test-LOSCondition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Condition,
        [Parameter(Mandatory)]
        [object] $Evidence
    )

    $field = [string] $Condition.Field
    $op = [string] $Condition.Operator
    $expected = $Condition.Value

    $value = Get-LOSFieldValue -Evidence $Evidence -Name $field

    switch ($op) {
        "Exists" {
            return -not [string]::IsNullOrWhiteSpace([string]$field) -and $null -ne $value
        }
        "Contains" {
            if ($null -eq $value) { return $false }
            $needle = [string]$expected
            $hay = [string]$value
            return $hay.Contains($needle)
        }
        "Equals" {
            if ($null -eq $value) { return $false }
            return ($value -eq $expected)
        }
        "NotEquals" {
            if ($null -eq $value) { return $false }
            return ($value -ne $expected)
        }
        "LessThan" {
            $num = Convert-LOSNumber -Value $value
            $exp = Convert-LOSNumber -Value $expected
            if ($null -eq $num -or $null -eq $exp) { return $false }
            return $num -lt $exp
        }
        "LessThanOrEqual" {
            $num = Convert-LOSNumber -Value $value
            $exp = Convert-LOSNumber -Value $expected
            if ($null -eq $num -or $null -eq $exp) { return $false }
            return $num -le $exp
        }
        "GreaterThan" {
            $num = Convert-LOSNumber -Value $value
            $exp = Convert-LOSNumber -Value $expected
            if ($null -eq $num -or $null -eq $exp) { return $false }
            return $num -gt $exp
        }
        "GreaterThanOrEqual" {
            $num = Convert-LOSNumber -Value $value
            $exp = Convert-LOSNumber -Value $expected
            if ($null -eq $num -or $null -eq $exp) { return $false }
            return $num -ge $exp
        }
        default { return $false }
    }
}

function Get-LOSPolicyMatchStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Policy,
        [Parameter(Mandatory)]
        [object] $Evidence
    )

    if (-not ($Policy.Enabled -eq $true)) {
        return [PSCustomObject][ordered]@{
            Matched         = $false
            MissingEvidence = $false
            Reason          = 'Disabled'
        }
    }

    $conditions = @($Policy.Conditions)
    if ($conditions.Count -eq 0) {
        return [PSCustomObject][ordered]@{
            Matched         = $false
            MissingEvidence = $false
            Reason          = 'NoConditions'
        }
    }

    foreach ($cond in $conditions) {
        if ($cond.PSObject.Properties.Name -contains 'All') {
            $allOk = $true
            foreach ($sub in @($cond.All)) {
                # Missing required evidence should fail closed for just this policy.
                if ([string]::IsNullOrWhiteSpace([string]$sub.Field)) {
                    return [PSCustomObject][ordered]@{
                        Matched         = $false
                        MissingEvidence = $false
                        Reason          = 'InvalidCondition'
                    }
                }

                if ($null -eq (Get-LOSFieldValue -Evidence $Evidence -Name ([string]$sub.Field))) {
                    return [PSCustomObject][ordered]@{
                        Matched         = $false
                        MissingEvidence = $true
                        Reason          = 'MissingEvidence'
                    }
                }

                if (-not (Test-LOSCondition -Condition $sub -Evidence $Evidence)) {
                    $allOk = $false
                }
            }

            if ($allOk -eq $false) {
                return [PSCustomObject][ordered]@{
                    Matched         = $false
                    MissingEvidence = $false
                    Reason          = 'ConditionMismatch'
                }
            }

            continue
        }

        $field = [string]$cond.Field
        if ([string]::IsNullOrWhiteSpace($field)) {
            return [PSCustomObject][ordered]@{
                Matched         = $false
                MissingEvidence = $false
                Reason          = 'InvalidCondition'
            }
        }

        if ($null -eq (Get-LOSFieldValue -Evidence $Evidence -Name $field)) {
            return [PSCustomObject][ordered]@{
                Matched         = $false
                MissingEvidence = $true
                Reason          = 'MissingEvidence'
            }
        }

        if (-not (Test-LOSCondition -Condition $cond -Evidence $Evidence)) {
            return [PSCustomObject][ordered]@{
                Matched         = $false
                MissingEvidence = $false
                Reason          = 'ConditionMismatch'
            }
        }
    }

    return [PSCustomObject][ordered]@{
        Matched         = $true
        MissingEvidence = $false
        Reason          = 'Matched'
    }
}

function Test-LOSPolicyMatch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Policy,
        [Parameter(Mandatory)]
        [object] $Evidence
    )

    return (Get-LOSPolicyMatchStatus -Policy $Policy -Evidence $Evidence).Matched
}

function Get-LOSPolicySeverityRank {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Severity
    )

    switch ($Severity) {
        "Critical" { return 3 }
        "Warning" { return 2 }
        "Info" { return 1 }
        default { return 0 }
    }
}

function Get-LOSPolicyOutcomeRank {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Outcome
    )

    switch ($Outcome) {
        "Deny" { return 7 }
        "Revoke" { return 6 }
        "Quarantine" { return 5 }
        "Escalate" { return 4 }
        "Recover" { return 3 }
        "Allow" { return 2 }
        "NoMatch" { return 1 }
        default { return 0 }
    }
}

function Invoke-LOSTrustPolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $SubjectId,

        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $Evidence,

        [string] $TimestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    )

    # Fail-closed on invalid evidence.
    if ($null -eq $Evidence) {
        $pol = [PSCustomObject][ordered]@{
            PolicyId = "__failclosed__"
            Severity = "Critical"
            Enabled = $true
            Actions = @([PSCustomObject][ordered]@{ Outcome = "Deny"; Severity = "Critical"; Reason = "InvalidEvidence" })
            Conditions = @()
        }
        $decisionId = "deny-failclosed"
        return [PSCustomObject][ordered]@{
            Success = $false
            Decision = (New-LOSPolicyDecision -DecisionId $decisionId -PolicyId $pol.PolicyId -SubjectId $SubjectId -Result "Deny" -Actions @(@{ Outcome = "Deny" }) -Severity "Critical" -TimestampUtc $TimestampUtc -Evidence $Evidence)
            Decisions = @()
        }
    }

    # Load applicable policies deterministically.
    $policies = @((Get-LOSPolicies))
    $policies = @($policies | Sort-Object PolicyId)

    $decisions = @()

    foreach ($policy in $policies) {
        $policyId = if ($null -ne $policy -and $policy.PSObject.Properties.Name -contains 'PolicyId') {
            $policy.PolicyId
        }
        else {
            '<unknown>'
        }

        $status = $null
        try {
            $status = Get-LOSPolicyMatchStatus -Policy $policy -Evidence $Evidence
        }
        catch {
            $status = [PSCustomObject][ordered]@{
                Matched         = $false
                MissingEvidence = $false
                Reason          = 'EvaluationError'
            }
        }

        if ($status.MissingEvidence -eq $true) {
            $decisionId = "{0}|MissingEvidence|{1}|{2}" -f $policyId, $SubjectId, $TimestampUtc
            $decision = New-LOSPolicyDecision -DecisionId $decisionId -PolicyId $policyId -SubjectId $SubjectId -Result 'Deny' -Actions @([PSCustomObject][ordered]@{ Outcome = 'Deny'; Severity = 'Critical'; Reason = 'MissingEvidence' }) -Severity 'Critical' -TimestampUtc $TimestampUtc -Evidence $Evidence
            $decisions += $decision
            continue
        }

        if (-not $status.Matched) { continue }

        # Convert first action to result; select highest severity among policies later.
        $actions = @($policy.Actions)
        foreach ($a in $actions) {
            $result = [string] $a.Outcome
            $severity = [string] $a.Severity
            $decisionId = "{0}|{1}|{2}|{3}" -f $policyId, $result, $SubjectId, $TimestampUtc
            $decision = New-LOSPolicyDecision -DecisionId $decisionId -PolicyId $policyId -SubjectId $SubjectId -Result $result -Actions @($a) -Severity $severity -TimestampUtc $TimestampUtc -Evidence $Evidence
            $decisions += $decision
            break
        }
    }

    $runtimeAuthorized = Get-LOSFieldValue -Evidence $Evidence -Name 'RuntimeAuthorized'
    $recoveryAttempts = Convert-LOSNumber -Value (Get-LOSFieldValue -Evidence $Evidence -Name 'RecoveryAttempts')
    if ($runtimeAuthorized -eq $false -and ($null -eq $recoveryAttempts -or $recoveryAttempts -lt 2)) {
        $runtimeDenyId = "runtime-authorized-false|$SubjectId|$TimestampUtc"
        $decisions += New-LOSPolicyDecision -DecisionId $runtimeDenyId -PolicyId 'runtime-policy-001' -SubjectId $SubjectId -Result 'Deny' -Actions @([PSCustomObject][ordered]@{ Outcome = 'Deny'; Severity = 'Critical'; Reason = 'RuntimeUnauthorized' }) -Severity 'Critical' -TimestampUtc $TimestampUtc -Evidence $Evidence
    }

    if ($decisions.Count -eq 0) {
        # Fail-closed outcome should be Deny.
        $denyDecision = New-LOSPolicyDecision -DecisionId ("__nomatch__" + $SubjectId) -PolicyId "__nomatch__" -SubjectId $SubjectId -Result "Deny" -Actions @([PSCustomObject][ordered]@{ Outcome = "Deny"; Severity = "Critical"; Reason = "NoPolicyMatch" }) -Severity "Critical" -TimestampUtc $TimestampUtc -Evidence $Evidence
        $script:TrustPolicyState.LastEvaluation = [PSCustomObject][ordered]@{ SubjectId = $SubjectId; Evidence = $Evidence; Decisions = $decisions; Selected = $denyDecision }
        return [PSCustomObject][ordered]@{ Success = $false; Decision = $denyDecision; Decisions = @($denyDecision) }
    }

    # Multiple matching policies: select deterministic highest-precedence outcome.
    $best = @(
        $decisions | Sort-Object `
            @{ Expression = { Get-LOSPolicyOutcomeRank -Outcome $_.Result }; Descending = $true }, `
            @{ Expression = { Get-LOSPolicySeverityRank -Severity $_.Severity }; Descending = $true }, `
            PolicyId, Result, DecisionId
    )[0]

    $script:TrustPolicyState.LastEvaluation = [PSCustomObject][ordered]@{ SubjectId = $SubjectId; Evidence = $Evidence; Decisions = $decisions; Selected = $best }

    return [PSCustomObject][ordered]@{ Success = ($best.Result -ne "Deny"); Decision = $best; Decisions = @($decisions) }
}

Export-ModuleMember -Function Invoke-LOSTrustPolicy, Test-LOSTrustPolicy, Get-LOSTrustPolicyState, Clear-LOSTrustPolicyState

