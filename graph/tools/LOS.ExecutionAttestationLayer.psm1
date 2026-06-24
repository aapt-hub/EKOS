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
$ErrorActionPreference = 'Stop'

$script:ModuleRoot = Split-Path -Parent $PSCommandPath

function Import-LosAttestationDependency {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName
    )

    $path = Join-Path $script:ModuleRoot ($ModuleName + '.psm1')
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required LOS attestation dependency not found: $ModuleName"
    }

    $resolvedPath = (Resolve-Path -LiteralPath $path).Path
    $module = Get-Module -Name $ModuleName | Select-Object -First 1
    if ($null -ne $module) {
        if (-not [StringComparer]::OrdinalIgnoreCase.Equals(
            [IO.Path]::GetFullPath($module.Path),
            [IO.Path]::GetFullPath($resolvedPath)
        )) {
            throw "Unauthorized LOS attestation dependency path for '$ModuleName'."
        }
        return $module
    }

    Import-Module -Name $resolvedPath -DisableNameChecking -ErrorAction Stop
    $module = Get-Module -Name $ModuleName | Select-Object -First 1
    if ($null -eq $module) {
        throw "Required LOS attestation dependency failed to load: $ModuleName"
    }

    return $module
}

function Get-LosAttestationCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Management.Automation.PSModuleInfo]$Module,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if (-not $Module.ExportedCommands.ContainsKey($Name)) {
        throw "LOS attestation dependency '$($Module.Name)' must export '$Name'."
    }

    return $Module.ExportedCommands[$Name]
}

$script:SerializerModule = Import-LosAttestationDependency `
    -ModuleName 'EKOS.CanonicalSerializer'
$script:RuntimeModule = Import-LosAttestationDependency `
    -ModuleName 'EKOS.GraphRuntime'
$script:RegistryModule = Import-LosAttestationDependency `
    -ModuleName 'LOS.ContractSchemaRegistry'

function Get-LosAttestationProperty {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [bool]$Required = $true
    )

    if ($InputObject -is [System.Collections.IDictionary]) {
        foreach ($key in $InputObject.Keys) {
            if ([StringComparer]::Ordinal.Equals(
                [string]$key,
                $Name
            )) {
                return $InputObject[$key]
            }
        }
    }

    $containsKey = $InputObject.PSObject.Methods['ContainsKey']
    if ($null -ne $containsKey -and
        [bool]$InputObject.ContainsKey($Name)) {
        return $InputObject[$Name]
    }

    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) {
        if ($Required) {
            throw "LOS attestation input is missing '$Name'."
        }
        return $null
    }

    return $property.Value
}

function Get-LosPostFlightHash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$InputObject
    )

    $serializer = Get-LosAttestationCommand `
        -Module $script:SerializerModule `
        -Name 'ConvertTo-EkosCanonicalJson'
    $canonicalJson = & $serializer -InputObject $InputObject
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha256.ComputeHash(
            [Text.Encoding]::UTF8.GetBytes($canonicalJson)
        )
    }
    finally {
        $sha256.Dispose()
    }

    return (($hash | ForEach-Object { $_.ToString('x2') }) -join '')
}

function ConvertTo-LosAttestationTimestamp {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value -or [string]::IsNullOrEmpty([string]$Value)) {
        return '1970-01-01T00:00:00.0000000Z'
    }

    $parsed = [datetime]::Parse(
        [string]$Value,
        [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::AssumeUniversal
    ).ToUniversalTime()

    return $parsed.ToString(
        "yyyy-MM-dd'T'HH:mm:ss.fffffff'Z'",
        [Globalization.CultureInfo]::InvariantCulture
    )
}

function New-LosReadOnlyRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Collections.IDictionary]$Values
    )

    $dictionary = New-Object `
        'Collections.Generic.Dictionary[string,object]' `
        (,[StringComparer]::Ordinal)
    foreach ($key in $Values.Keys) {
        $dictionary.Add([string]$key, $Values[$key])
    }

    $readOnly = New-Object `
        'Collections.ObjectModel.ReadOnlyDictionary[string,object]' `
        (,$dictionary)
    Write-Output -NoEnumerate $readOnly
}

function New-LosExecutionAttestation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$ExecutionRecord
    )

    $contractId = [string](Get-LosAttestationProperty `
        -InputObject $ExecutionRecord `
        -Name 'ContractId')
    $contractVersion = [string](Get-LosAttestationProperty `
        -InputObject $ExecutionRecord `
        -Name 'Version')
    $providedSchemaHash = [string](Get-LosAttestationProperty `
        -InputObject $ExecutionRecord `
        -Name 'SchemaHash')
    $executionOutput = Get-LosAttestationProperty `
        -InputObject $ExecutionRecord `
        -Name 'ExecutionOutput'
    $executionTrace = @(
        Get-LosAttestationProperty `
            -InputObject $ExecutionRecord `
            -Name 'ExecutionTrace'
    )

    if ([string]::IsNullOrEmpty($contractId) -or
        [string]::IsNullOrEmpty($contractVersion) -or
        [string]::IsNullOrEmpty($providedSchemaHash)) {
        throw 'LOS attestation identity fields cannot be empty.'
    }

    $runtimeCommand = Get-LosAttestationCommand `
        -Module $script:RuntimeModule `
        -Name 'Get-EkosRuntimeInfo'
    $runtimeInfo = & $runtimeCommand
    $runtime = if ([bool]$runtimeInfo.IsCore) { 'PS7' } else { 'PS5.1' }

    $resolveCommand = Get-LosAttestationCommand `
        -Module $script:RegistryModule `
        -Name 'Resolve-ContractSchema'
    $schema = & $resolveCommand `
        -ContractId $contractId `
        -Version $contractVersion `
        -RuntimeContext $runtimeInfo
    $actualSchemaHash = Get-LosPostFlightHash -InputObject $schema
    if (-not [StringComparer]::Ordinal.Equals(
        $providedSchemaHash,
        $actualSchemaHash
    )) {
        throw 'LOS attestation failed: schema hash mismatch.'
    }

    $inputEnvelope = if (
        $null -ne $executionOutput -and
        $null -ne $executionOutput.PSObject.Properties['InputPayload'] -and
        $null -ne $executionOutput.PSObject.Properties['ExecutionContext']
    ) {
        [pscustomobject][ordered]@{
            inputPayload     = $executionOutput.InputPayload
            executionContext = $executionOutput.ExecutionContext
        }
    }
    else {
        Get-LosAttestationProperty `
            -InputObject $ExecutionRecord `
            -Name 'ExecutionInput'
    }

    $inputHash = Get-LosPostFlightHash -InputObject $inputEnvelope
    $outputHash = Get-LosPostFlightHash -InputObject $executionOutput
    $executionPathHash = Get-LosPostFlightHash -InputObject $executionTrace
    $status = if ($null -ne $ExecutionRecord.PSObject.Properties['Status']) {
        [string]$ExecutionRecord.Status
    }
    else {
        'PASS'
    }
    if ($status -notin @('PASS', 'FAIL')) {
        throw "LOS attestation status is invalid: $status"
    }

    $signatureMaterial = [pscustomobject][ordered]@{
        contractId       = $contractId
        contractVersion  = $contractVersion
        inputHash        = $inputHash
        outputHash       = $outputHash
        schemaHash       = $providedSchemaHash
        executionPathHash = $executionPathHash
        status           = $status
    }
    $signature = Get-LosPostFlightHash -InputObject $signatureMaterial
    $attestationId = Get-LosPostFlightHash -InputObject (
        [pscustomobject][ordered]@{
            type                   = 'LOS-DCEK-EXECUTION-ATTESTATION'
            deterministicSignature = $signature
        }
    )

    $timestampValue = Get-LosAttestationProperty `
        -InputObject $ExecutionRecord `
        -Name 'Timestamp' `
        -Required $false
    $timestamp = ConvertTo-LosAttestationTimestamp -Value $timestampValue
    $parityValidated = (
        [bool]$schema.compatibilityValidated -and
        [bool]$schema.compatibility.PS5 -and
        [bool]$schema.compatibility.PS7
    )

    return New-LosReadOnlyRecord -Values ([ordered]@{
        attestationId          = $attestationId
        contractId             = $contractId
        contractVersion        = $contractVersion
        runtime                = $runtime
        inputHash              = $inputHash
        outputHash             = $outputHash
        schemaHash             = $providedSchemaHash
        executionPathHash      = $executionPathHash
        deterministicSignature = $signature
        timestamp              = $timestamp
        status                 = $status
        parityValidated        = [bool]$parityValidated
        isValid                = $true
    })
}

Export-ModuleMember -Function New-LosExecutionAttestation
