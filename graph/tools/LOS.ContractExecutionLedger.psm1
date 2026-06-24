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

$script:SerializerPath = Join-Path `
    (Split-Path -Parent $PSCommandPath) `
    'EKOS.CanonicalSerializer.psm1'
if (-not (Test-Path -LiteralPath $script:SerializerPath -PathType Leaf)) {
    throw 'Required LOS ledger dependency not found: EKOS.CanonicalSerializer'
}

$resolvedSerializerPath = (Resolve-Path -LiteralPath $script:SerializerPath).Path
$script:SerializerModule = Get-Module -Name 'EKOS.CanonicalSerializer' |
    Select-Object -First 1
if ($null -ne $script:SerializerModule) {
    if (-not [StringComparer]::OrdinalIgnoreCase.Equals(
        [IO.Path]::GetFullPath($script:SerializerModule.Path),
        [IO.Path]::GetFullPath($resolvedSerializerPath)
    )) {
        throw 'Unauthorized LOS ledger serializer path.'
    }
}
else {
    Import-Module `
        -Name $resolvedSerializerPath `
        -DisableNameChecking `
        -ErrorAction Stop
    $script:SerializerModule = Get-Module `
        -Name 'EKOS.CanonicalSerializer' |
        Select-Object -First 1
}

function Get-LosLedgerHash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$InputObject
    )

    $serializer = $script:SerializerModule.ExportedCommands[
        'ConvertTo-EkosCanonicalJson'
    ]
    if ($null -eq $serializer) {
        throw 'LOS ledger serializer export is unavailable.'
    }

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

function Get-LosLedgerChainedHash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Material,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$PreviousLedgerHash
    )

    $serializer = $script:SerializerModule.ExportedCommands[
        'ConvertTo-EkosCanonicalJson'
    ]
    if ($null -eq $serializer) {
        throw 'LOS ledger serializer export is unavailable.'
    }

    $canonicalJson = & $serializer -InputObject $Material
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha256.ComputeHash(
            [Text.Encoding]::UTF8.GetBytes(
                $canonicalJson + $PreviousLedgerHash
            )
        )
    }
    finally {
        $sha256.Dispose()
    }

    return (($hash | ForEach-Object { $_.ToString('x2') }) -join '')
}

function Get-LosLedgerValue {
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
        throw "LOS ledger input is missing '$Name'."
    }
    return $property.Value
}

function New-LosReadOnlyLedgerEntry {
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

function Get-LosLedgerMaterial {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Entry
    )

    return [pscustomobject][ordered]@{
        sequenceNumber       = [int64](Get-LosLedgerValue $Entry 'sequenceNumber')
        previousLedgerHash   = [string](Get-LosLedgerValue $Entry 'previousLedgerHash')
        contractId           = [string](Get-LosLedgerValue $Entry 'contractId')
        inputHash            = [string](Get-LosLedgerValue $Entry 'inputHash')
        outputHash           = [string](Get-LosLedgerValue $Entry 'outputHash')
        schemaHash           = [string](Get-LosLedgerValue $Entry 'schemaHash')
        executionPathHash    = [string](Get-LosLedgerValue $Entry 'executionPathHash')
        attestationSignature = [string](Get-LosLedgerValue $Entry 'attestationSignature')
        runtime              = [string](Get-LosLedgerValue $Entry 'runtime')
        status               = [string](Get-LosLedgerValue $Entry 'status')
    }
}

function Test-LosContractExecutionLedger {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]]$Ledger
    )

    $entries = @($Ledger)
    $previousHash = ''
    $expectedSequence = [int64]1

    try {
        foreach ($entry in $entries) {
            $material = Get-LosLedgerMaterial -Entry $entry
            if ([int64]$material.sequenceNumber -ne $expectedSequence) {
                throw "LOS ledger sequence mismatch at $expectedSequence."
            }
            if (-not [StringComparer]::Ordinal.Equals(
                [string]$material.previousLedgerHash,
                $previousHash
            )) {
                throw "LOS ledger previous hash mismatch at $expectedSequence."
            }

            $expectedHash = Get-LosLedgerChainedHash `
                -Material $material `
                -PreviousLedgerHash $previousHash
            if (-not [StringComparer]::Ordinal.Equals(
                [string](Get-LosLedgerValue $entry 'ledgerHash'),
                $expectedHash
            ) -or
                -not [StringComparer]::Ordinal.Equals(
                    [string](Get-LosLedgerValue $entry 'ledgerEntryId'),
                    $expectedHash
                )) {
                throw "LOS ledger hash mismatch at $expectedSequence."
            }

            $previousHash = $expectedHash
            $expectedSequence++
        }

        return [pscustomobject][ordered]@{
            IsValid      = $true
            Status       = 'PASS'
            EntryCount   = $entries.Count
            TerminalHash = $previousHash
            Error        = $null
        }
    }
    catch {
        return [pscustomobject][ordered]@{
            IsValid      = $false
            Status       = 'FAIL'
            EntryCount   = $entries.Count
            TerminalHash = $previousHash
            Error        = [pscustomobject][ordered]@{
                Type    = $_.Exception.GetType().FullName
                Message = $_.Exception.Message
            }
        }
    }
}

function Add-LosContractExecutionLedgerEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Entry,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]]$Ledger = @()
    )

    $history = @($Ledger)
    $chainResult = Test-LosContractExecutionLedger -Ledger $history
    if (-not [bool]$chainResult.IsValid) {
        return [pscustomobject][ordered]@{
            Accepted      = $false
            ReplayDetected = $false
            Status        = 'FAIL'
            Error         = $chainResult.Error
            LedgerEntryId = ''
        }
    }

    $attestation = Get-LosLedgerValue -InputObject $Entry -Name 'Attestation'
    $signature = [string](Get-LosLedgerValue `
        -InputObject $attestation `
        -Name 'deterministicSignature')
    $expectedSignature = Get-LosLedgerHash -InputObject (
        [pscustomobject][ordered]@{
            contractId       = [string](Get-LosLedgerValue `
                $attestation `
                'contractId')
            contractVersion  = [string](Get-LosLedgerValue `
                $attestation `
                'contractVersion')
            inputHash        = [string](Get-LosLedgerValue `
                $attestation `
                'inputHash')
            outputHash       = [string](Get-LosLedgerValue `
                $attestation `
                'outputHash')
            schemaHash       = [string](Get-LosLedgerValue `
                $attestation `
                'schemaHash')
            executionPathHash = [string](Get-LosLedgerValue `
                $attestation `
                'executionPathHash')
            status           = [string](Get-LosLedgerValue `
                $attestation `
                'status')
        }
    )
    if (-not [StringComparer]::Ordinal.Equals(
        $signature,
        $expectedSignature
    ) -or
        -not [bool](Get-LosLedgerValue $attestation 'isValid') -or
        -not [StringComparer]::Ordinal.Equals(
            [string](Get-LosLedgerValue $Entry 'ContractId'),
            [string](Get-LosLedgerValue $attestation 'contractId')
        ) -or
        -not [StringComparer]::Ordinal.Equals(
            [string](Get-LosLedgerValue $Entry 'SchemaHash'),
            [string](Get-LosLedgerValue $attestation 'schemaHash')
        ) -or
        -not [StringComparer]::Ordinal.Equals(
            [string](Get-LosLedgerValue $Entry 'OutputHash'),
            [string](Get-LosLedgerValue $attestation 'outputHash')
        )) {
        return [pscustomobject][ordered]@{
            Accepted       = $false
            ReplayDetected = $false
            Status         = 'FAIL'
            Error          = [pscustomobject][ordered]@{
                Type    = 'LOS.AttestationMismatch'
                Message = 'Ledger input does not match its attestation.'
            }
            LedgerEntryId  = ''
        }
    }

    foreach ($existing in $history) {
        if ([StringComparer]::Ordinal.Equals(
            [string](Get-LosLedgerValue `
                $existing `
                'attestationSignature'),
            $signature
        )) {
            return [pscustomobject][ordered]@{
                Accepted       = $false
                ReplayDetected = $true
                Status         = 'FAIL'
                Error          = [pscustomobject][ordered]@{
                    Type    = 'LOS.ReplayDetected'
                    Message = 'Duplicate attestation signature rejected.'
                }
                LedgerEntryId  = ''
            }
        }
    }

    $previousHash = [string]$chainResult.TerminalHash
    $material = [pscustomobject][ordered]@{
        sequenceNumber       = [int64]($history.Count + 1)
        previousLedgerHash   = $previousHash
        contractId           = [string](Get-LosLedgerValue $attestation 'contractId')
        inputHash            = [string](Get-LosLedgerValue $attestation 'inputHash')
        outputHash           = [string](Get-LosLedgerValue $attestation 'outputHash')
        schemaHash           = [string](Get-LosLedgerValue $attestation 'schemaHash')
        executionPathHash    = [string](Get-LosLedgerValue $attestation 'executionPathHash')
        attestationSignature = $signature
        runtime              = [string](Get-LosLedgerValue $attestation 'runtime')
        status               = [string](Get-LosLedgerValue $attestation 'status')
    }
    $ledgerHash = Get-LosLedgerChainedHash `
        -Material $material `
        -PreviousLedgerHash $previousHash

    return New-LosReadOnlyLedgerEntry -Values ([ordered]@{
        sequenceNumber       = $material.sequenceNumber
        ledgerEntryId        = $ledgerHash
        previousLedgerHash   = $material.previousLedgerHash
        contractId           = $material.contractId
        inputHash            = $material.inputHash
        outputHash           = $material.outputHash
        schemaHash           = $material.schemaHash
        executionPathHash    = $material.executionPathHash
        attestationSignature = $material.attestationSignature
        runtime              = $material.runtime
        status               = $material.status
        ledgerHash           = $ledgerHash
        Accepted             = $true
        ReplayDetected       = $false
        Error                = $null
    })
}

Export-ModuleMember -Function @(
    'Add-LosContractExecutionLedgerEntry',
    'Test-LosContractExecutionLedger'
)
