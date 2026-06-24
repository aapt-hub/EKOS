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

function New-LosPolicyDenyResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Reason
    )

    [PSCustomObject][ordered]@{
        Success  = $false
        Decision = "DENY"
        Reason   = $Reason
    }
}

function ConvertTo-LosStableJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowNull()]
        $InputObject
    )

    process {
        if ($null -eq $InputObject) {
            return "null"
        }

        if ($InputObject -is [string]) {
            return ($InputObject | ConvertTo-Json -Compress)
        }

        if ($InputObject -is [bool]) {
            return ($InputObject | ConvertTo-Json -Compress)
        }

        if ($InputObject -is [int] -or $InputObject -is [long] -or $InputObject -is [double] -or $InputObject -is [decimal]) {
            return ([string]::Format([System.Globalization.CultureInfo]::InvariantCulture, "{0}", $InputObject))
        }

        if ($InputObject -is [System.Collections.IDictionary]) {
            $parts = New-Object System.Collections.Generic.List[string]
            foreach ($key in @($InputObject.Keys | Sort-Object)) {
                $parts.Add((($key | ConvertTo-Json -Compress) + ":" + (ConvertTo-LosStableJson -InputObject $InputObject[$key])))
            }
            return "{" + ($parts -join ",") + "}"
        }

        if ($InputObject -is [System.Collections.IEnumerable] -and -not ($InputObject -is [string])) {
            $items = New-Object System.Collections.Generic.List[string]
            foreach ($item in $InputObject) {
                $items.Add((ConvertTo-LosStableJson -InputObject $item))
            }
            return "[" + ($items -join ",") + "]"
        }

        $map = [ordered]@{}
        foreach ($property in @($InputObject.PSObject.Properties | Sort-Object Name)) {
            $map[$property.Name] = $property.Value
        }
        ConvertTo-LosStableJson -InputObject $map
    }
}

function Get-LosSha256String {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Value
    )

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
        $hash = $sha.ComputeHash($bytes)
        -join ($hash | ForEach-Object { $_.ToString("x2") })
    }
    finally {
        if ($sha -is [System.IDisposable]) {
            $sha.Dispose()
        }
    }
}

function Invoke-LosPolicyEvaluation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Contract,

        [Parameter(Mandatory)]
        [string] $Runtime,

        [hashtable] $ExecutionContext = @{},

        [string[]] $RequiredCapabilities = @()
    )

    try {
        if ($null -eq $Contract) {
            return New-LosPolicyDenyResult -Reason "ContractMissing"
        }

        if ([string]::IsNullOrWhiteSpace($Runtime)) {
            return New-LosPolicyDenyResult -Reason "RuntimeMissing"
        }

        if (-not ($Contract.PSObject.Properties.Name -contains "runtime")) {
            return New-LosPolicyDenyResult -Reason "RuntimePolicyMissing"
        }

        $allowedRuntimes = @($Contract.runtime)
        if ($allowedRuntimes -notcontains $Runtime) {
            return New-LosPolicyDenyResult -Reason "RuntimeNotAuthorized"
        }

        if (-not ($Contract.PSObject.Properties.Name -contains "deterministic") -or $Contract.deterministic -ne $true) {
            return New-LosPolicyDenyResult -Reason "DeterminismRequired"
        }

        $capabilities = @()
        if ($ExecutionContext.ContainsKey("Capabilities")) {
            $capabilities = @($ExecutionContext["Capabilities"])
        }

        foreach ($requiredCapability in $RequiredCapabilities) {
            if ($capabilities -notcontains $requiredCapability) {
                return New-LosPolicyDenyResult -Reason "PolicyViolation"
            }
        }

        $policyFacts = [ordered]@{
            ContractId           = $Contract.contractId
            ContractVersion      = $Contract.version
            Runtime              = $Runtime
            Deterministic        = $Contract.deterministic
            RequiredCapabilities = @($RequiredCapabilities | Sort-Object)
        }
        $policyHash = Get-LosSha256String -Value (ConvertTo-LosStableJson -InputObject $policyFacts)

        [PSCustomObject][ordered]@{
            Success    = $true
            Decision   = "ALLOW"
            PolicyHash = $policyHash
        }
    }
    catch {
        New-LosPolicyDenyResult -Reason "PolicyEvaluationError"
    }
}

Export-ModuleMember -Function Invoke-LosPolicyEvaluation, ConvertTo-LosStableJson, Get-LosSha256String
