<#
AUTHOR:
Abner Pauneto

COPYRIGHT:
Copyright (c) 2026 Abner Pauneto

LICENSE:
Proprietary  All Rights Reserved

PROJECT:
EKOS

STATUS:
Private Development
#>

<#
.SYNOPSIS
LOS Policy Registry.

.DESCRIPTION
Deterministic, fail-closed Runtime Trust Policy Registry for LOS-TRUST-005.

Loads and validates JSON policy artifacts from los/policies.

Exports: Register-LOSPolicy, Remove-LOSPolicy, Get-LOSPolicy, Get-LOSPolicies, Test-LOSPolicy.
#>
Set-StrictMode -Version Latest

# In-memory registry.
$script:Registry = [ordered]@{}
$script:PolicyRegistryLoadErrors = @()

$script:SupportedOperators = @(
    "Equals",
    "NotEquals",
    "LessThan",
    "LessThanOrEqual",
    "GreaterThan",
    "GreaterThanOrEqual",
    "Contains",
    "Exists"
)

$script:SupportedOutcomes = @(
    "Allow",
    "Deny",
    "Quarantine",
    "Revoke",
    "Escalate",
    "Recover",
    "NoMatch"
)

$script:SupportedSeverity = @("Info", "Warning", "Critical")

function Resolve-LOSPolicyRootPath {
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string] $RootPath
    )

    if (-not [string]::IsNullOrWhiteSpace($RootPath)) {
        return (Resolve-Path -LiteralPath $RootPath -ErrorAction Stop).Path
    }

    $moduleRoot = $PSScriptRoot
    if ([string]::IsNullOrWhiteSpace($moduleRoot) -and -not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
        $moduleRoot = Split-Path -Parent $PSCommandPath
    }

    if ([string]::IsNullOrWhiteSpace($moduleRoot)) {
        throw "RootPathResolutionFailed"
    }

    return (Resolve-Path -LiteralPath (Join-Path $moduleRoot "..\..") -ErrorAction Stop).Path
}

function Get-LOSPolicyDirectory {
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string] $RootPath
    )

    $resolvedRoot = Resolve-LOSPolicyRootPath -RootPath $RootPath
    return (Join-Path $resolvedRoot "los\policies")
}

function ConvertFrom-JsonFailClosed {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Json
    )

    try {
        return ConvertFrom-Json -InputObject $Json -ErrorAction Stop
    }
    catch {
        throw "MalformedJson"
    }
}

function Test-LOSPolicyRequiredFields {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Policy
    )

    $required = @(
        "PolicyId",
        "Name",
        "Version",
        "Enabled",
        "Scope",
        "Conditions",
        "Actions",
        "Severity",
        "CreatedBy",
        "CreatedUtc"
    )

    foreach ($name in $required) {
        if ($null -eq $Policy.$name) {
            return $false
        }
    }

    if (-not ($Policy.Enabled -is [bool])) {
        return $false
    }

    if ($null -eq $Policy.Conditions -or -not ($Policy.Conditions -is [System.Collections.IEnumerable])) {
        return $false
    }

    if ($null -eq $Policy.Actions -or -not ($Policy.Actions -is [System.Collections.IEnumerable])) {
        return $false
    }

    return $true
}

function Test-LOSPolicyOperatorsAndActions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Policy
    )

    foreach ($cond in @($Policy.Conditions)) {
        # Support two shapes used by samples:
        #  - simple: { Field, Operator, Value }
        #  - composite: { All: [ {Field,Operator,Value}, ... ] }
        if ($null -ne $cond.PSObject.Properties['All']) {
            foreach ($sub in @($cond.All)) {
                if ($null -eq $sub.Operator -or $sub.Operator -notin $script:SupportedOperators) {
                    return $false
                }
            }
            continue
        }

        # simple condition
        if ($null -eq $cond.Operator) {
            return $false
        }
        if ($cond.Operator -notin $script:SupportedOperators) {
            return $false
        }
    }

    foreach ($action in @($Policy.Actions)) {
        if ($null -eq $action.Outcome -or $action.Outcome -notin $script:SupportedOutcomes) {
            return $false
        }
        if ($null -eq $action.Severity -or $action.Severity -notin $script:SupportedSeverity) {
            return $false
        }
    }

    if ($null -eq $Policy.Severity -or $Policy.Severity -notin $script:SupportedSeverity) {
        return $false
    }

    return $true
}

function Test-LOSPolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $Policy
    )

    if ($null -eq $Policy) {
        return [PSCustomObject][ordered]@{ Valid = $false; Reason = "PolicyMissing" }
    }

    if (-not (Test-LOSPolicyRequiredFields -Policy $Policy)) {
        return [PSCustomObject][ordered]@{ Valid = $false; Reason = "PolicyInvalidMissingFields" }
    }

    if (-not (Test-LOSPolicyOperatorsAndActions -Policy $Policy)) {
        return [PSCustomObject][ordered]@{ Valid = $false; Reason = "PolicyInvalidOperatorsOrActions" }
    }

    return [PSCustomObject][ordered]@{ Valid = $true; Reason = "OK" }
}

function Register-LOSPolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Policy,

        [AllowEmptyString()]
        [string] $RootPath
    )

    $test = Test-LOSPolicy -Policy $Policy
    if (-not $test.Valid) {
        throw "InvalidPolicy: $($test.Reason)"
    }

    $policyId = [string] $Policy.PolicyId
    if ([string]::IsNullOrWhiteSpace($policyId)) {
        throw "InvalidPolicy: PolicyIdMissing"
    }

    if ($script:Registry.Contains($policyId)) {
        throw "DuplicatePolicyId: $policyId"
    }

    $script:Registry[$policyId] = $Policy
    return $Policy
}

function Remove-LOSPolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $PolicyId
    )

    if ($script:Registry.Contains($PolicyId)) {
        $null = $script:Registry.Remove($PolicyId)
    }

    return [PSCustomObject][ordered]@{ Success = $true; PolicyId = $PolicyId }
}

function Get-LOSPolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $PolicyId
    )

    if ($script:Registry.Contains($PolicyId)) {
        return $script:Registry[$PolicyId]
    }

    return $null
}

function Get-LOSPolicies {
    [CmdletBinding()]
    param()

    return @($script:Registry.Values | Sort-Object PolicyId)
}

function Get-LOSPolicyRegistryLoadErrors {
    [CmdletBinding()]
    param()

    return $script:PolicyRegistryLoadErrors
}

function Import-LOSPoliciesFromDefaultPath {
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string] $RootPath
    )

    $policyDir = Get-LOSPolicyDirectory -RootPath $RootPath
    if (-not (Test-Path -LiteralPath $policyDir)) {
        throw "PoliciesMissing"
    }

    $policyFiles = @(Get-ChildItem -LiteralPath $policyDir -Filter "*.json" -File | Sort-Object Name)
    if ($policyFiles.Count -eq 0) {
        throw "PoliciesMissing"
    }

    foreach ($file in $policyFiles) {
        try {
            $raw = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop
            $policy = ConvertFrom-JsonFailClosed -Json $raw

            $test = Test-LOSPolicy -Policy $policy
            if (-not $test.Valid) {
                throw "InvalidPolicy: $($test.Reason)"
            }

            if ($script:Registry.Contains([string]$policy.PolicyId)) {
                $script:PolicyRegistryLoadErrors += [PSCustomObject][ordered]@{
                    File = $file.FullName
                    Error = "DuplicatePolicyId: $($policy.PolicyId)"
                }
                continue
            }

            $script:Registry[[string]$policy.PolicyId] = $policy
        }
        catch {
            $script:PolicyRegistryLoadErrors += [PSCustomObject][ordered]@{
                File = $file.FullName
                Error = $_.Exception.Message
            }
        }
    }
}

# Eager load on first module import.
$script:__LOS_PolicyRegistryInitialized = $false
try {
    if (-not $script:__LOS_PolicyRegistryInitialized) {
        $script:__LOS_PolicyRegistryInitialized = $true
        Import-LOSPoliciesFromDefaultPath | Out-Null
    }
}
catch {
    # Fail-closed: keep registry empty, but capture diagnostics.
    $script:PolicyRegistryLoadErrors += [PSCustomObject][ordered]@{
        File = "<module-init>"
        Error = $_.Exception.Message
    }
    $script:Registry = [ordered]@{}
}

Export-ModuleMember -Function Register-LOSPolicy, Remove-LOSPolicy, Get-LOSPolicy, Get-LOSPolicies, Test-LOSPolicy, Get-LOSPolicyRegistryLoadErrors

