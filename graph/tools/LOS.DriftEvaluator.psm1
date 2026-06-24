Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ModuleRoot = Split-Path -Parent $PSCommandPath

function Import-LosDriftDependency {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName
    )

    $path = Join-Path $script:ModuleRoot ($ModuleName + '.psm1')
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required LOS drift dependency not found: $ModuleName"
    }
    $resolvedPath = (Resolve-Path -LiteralPath $path).Path
    $module = Get-Module -Name $ModuleName | Select-Object -First 1
    if ($null -ne $module) {
        if (-not [StringComparer]::OrdinalIgnoreCase.Equals(
            [IO.Path]::GetFullPath($module.Path),
            [IO.Path]::GetFullPath($resolvedPath)
        )) {
            throw "Unauthorized LOS drift dependency path for '$ModuleName'."
        }
        return $module
    }

    Import-Module -Name $resolvedPath -DisableNameChecking -ErrorAction Stop
    return Get-Module -Name $ModuleName | Select-Object -First 1
}

$script:SerializerModule = Import-LosDriftDependency `
    -ModuleName 'EKOS.CanonicalSerializer'
$script:AttestationModule = Import-LosDriftDependency `
    -ModuleName 'LOS.ExecutionAttestationLayer'
$script:LedgerModule = Import-LosDriftDependency `
    -ModuleName 'LOS.ContractExecutionLedger'

function Get-LosDriftCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Management.Automation.PSModuleInfo]$Module,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if (-not $Module.ExportedCommands.ContainsKey($Name)) {
        throw "LOS drift dependency '$($Module.Name)' must export '$Name'."
    }
    return $Module.ExportedCommands[$Name]
}

function Get-LosDriftHash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$InputObject
    )

    $serializer = Get-LosDriftCommand `
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

function Get-LosDriftValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string]$Name
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
        throw "LOS drift record is missing '$Name'."
    }
    return $property.Value
}

function ConvertTo-LosComparableAttestation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Record
    )

    $isAttestation = $false
    try {
        [void](Get-LosDriftValue $Record 'deterministicSignature')
        [void](Get-LosDriftValue $Record 'inputHash')
        [void](Get-LosDriftValue $Record 'outputHash')
        $isAttestation = $true
    }
    catch {
        $isAttestation = $false
    }

    if ($isAttestation) {
        $expectedSignature = Get-LosDriftHash -InputObject (
            [pscustomobject][ordered]@{
                contractId       = [string](Get-LosDriftValue `
                    $Record `
                    'contractId')
                contractVersion  = [string](Get-LosDriftValue `
                    $Record `
                    'contractVersion')
                inputHash        = [string](Get-LosDriftValue `
                    $Record `
                    'inputHash')
                outputHash       = [string](Get-LosDriftValue `
                    $Record `
                    'outputHash')
                schemaHash       = [string](Get-LosDriftValue `
                    $Record `
                    'schemaHash')
                executionPathHash = [string](Get-LosDriftValue `
                    $Record `
                    'executionPathHash')
                status           = [string](Get-LosDriftValue `
                    $Record `
                    'status')
            }
        )
        if (-not [StringComparer]::Ordinal.Equals(
            [string](Get-LosDriftValue `
                $Record `
                'deterministicSignature'),
            $expectedSignature
        )) {
            throw 'LOS drift validation failed: attestation signature mismatch.'
        }
        return ,$Record
    }

    $command = Get-LosDriftCommand `
        -Module $script:AttestationModule `
        -Name 'New-LosExecutionAttestation'
    return & $command -ExecutionRecord $Record
}

function Test-LosExecutionDrift {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$ExpectedRecord,

        [Parameter(Mandatory)]
        [object]$ActualRecord,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]]$Ledger = @()
    )

    $anomalies = New-Object 'Collections.Generic.List[object]'

    try {
        $expected = ConvertTo-LosComparableAttestation `
            -Record $ExpectedRecord
        $actual = ConvertTo-LosComparableAttestation `
            -Record $ActualRecord

        foreach ($field in @(
            'contractId',
            'contractVersion',
            'inputHash',
            'outputHash',
            'schemaHash',
            'executionPathHash',
            'deterministicSignature',
            'status'
        )) {
            $expectedValue = [string](Get-LosDriftValue $expected $field)
            $actualValue = [string](Get-LosDriftValue $actual $field)
            if (-not [StringComparer]::Ordinal.Equals(
                $expectedValue,
                $actualValue
            )) {
                $anomalies.Add([pscustomobject][ordered]@{
                    type     = 'HASH_DIVERGENCE'
                    field    = $field
                    expected = $expectedValue
                    actual   = $actualValue
                })
            }
        }

        $ledgerCommand = Get-LosDriftCommand `
            -Module $script:LedgerModule `
            -Name 'Test-LosContractExecutionLedger'
        $ledgerResult = & $ledgerCommand -Ledger @($Ledger)
        if (-not [bool]$ledgerResult.IsValid) {
            $anomalies.Add([pscustomobject][ordered]@{
                type     = 'LEDGER_CHAIN_DIVERGENCE'
                field    = 'ledger'
                expected = 'VALID'
                actual   = 'INVALID'
            })
        }

        $replayDetected = $false
        $signatureMatches = @(
            @($Ledger) |
                Where-Object {
                    [StringComparer]::Ordinal.Equals(
                        [string](Get-LosDriftValue `
                            $_ `
                            'attestationSignature'),
                        [string](Get-LosDriftValue `
                            $actual `
                            'deterministicSignature')
                    )
                }
        )
        if ($signatureMatches.Count -gt 1) {
            $replayDetected = $true
            $anomalies.Add([pscustomobject][ordered]@{
                type     = 'REPLAY_DETECTED'
                field    = 'attestationSignature'
                expected = 'UNIQUE'
                actual   = 'DUPLICATE'
            })
        }

        $driftDetected = ($anomalies.Count -gt 0)
        return [pscustomobject][ordered]@{
            Status            = if ($driftDetected) {
                'DRIFT_DETECTED'
            }
            else {
                'PASS'
            }
            IsValid           = $true
            DriftDetected     = $driftDetected
            ReplayDetected    = $replayDetected
            ParityValidated   = (
                -not $driftDetected -and
                [bool](Get-LosDriftValue $expected 'parityValidated') -and
                [bool](Get-LosDriftValue $actual 'parityValidated')
            )
            ExpectedSignature = [string](Get-LosDriftValue `
                $expected `
                'deterministicSignature')
            ActualSignature   = [string](Get-LosDriftValue `
                $actual `
                'deterministicSignature')
            ComparisonHash    = Get-LosDriftHash -InputObject (
                [pscustomobject][ordered]@{
                    expected = [string](Get-LosDriftValue `
                        $expected `
                        'deterministicSignature')
                    actual   = [string](Get-LosDriftValue `
                        $actual `
                        'deterministicSignature')
                    anomalies = @($anomalies.ToArray())
                }
            )
            Anomalies         = @($anomalies.ToArray())
            Error             = $null
        }
    }
    catch {
        return [pscustomobject][ordered]@{
            Status            = 'FAIL'
            IsValid           = $false
            DriftDetected     = $true
            ReplayDetected    = $false
            ParityValidated   = $false
            ExpectedSignature = ''
            ActualSignature   = ''
            ComparisonHash    = ''
            Anomalies         = @()
            Error             = [pscustomobject][ordered]@{
                Type    = $_.Exception.GetType().FullName
                Message = $_.Exception.Message
            }
        }
    }
}

Export-ModuleMember -Function Test-LosExecutionDrift
