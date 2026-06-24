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

$runtimePath = Join-Path $PSScriptRoot 'EKOS.GraphRuntime.psm1'
$resolvedRuntimePath = (Resolve-Path -LiteralPath $runtimePath).Path
$runtimeModule = Get-Module -Name 'EKOS.GraphRuntime' |
    Select-Object -First 1
if ($null -ne $runtimeModule) {
    if (-not [System.StringComparer]::OrdinalIgnoreCase.Equals(
        [System.IO.Path]::GetFullPath($runtimeModule.Path),
        [System.IO.Path]::GetFullPath($resolvedRuntimePath)
    )) {
        throw 'Unauthorized LOS audit runtime module path.'
    }
}
else {
    Import-Module $resolvedRuntimePath -ErrorAction Stop
}

function Get-LosAuditProperty {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Record,

        [Parameter(Mandatory)]
        [string]$Name
    )

    foreach ($property in $Record.PSObject.Properties) {
        if ([System.StringComparer]::Ordinal.Equals(
            $property.Name,
            $Name
        )) {
            return [PSCustomObject]@{
                Exists = $true
                Value  = $property.Value
            }
        }
    }

    return [PSCustomObject]@{
        Exists = $false
        Value  = $null
    }
}

function Write-LosContractAuditRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Record
    )

    $requiredProperties = @(
        'ContractId',
        'Version',
        'SchemaHash',
        'Status',
        'ContractResolved',
        'SchemaLoaded',
        'VersionValidated',
        'SchemaValidated',
        'IntegrityVerified',
        'PreflightExecuted',
        'ExecutionResult',
        'PostflightValidated',
        'Error'
    )

    $resolved = @{}
    foreach ($propertyName in $requiredProperties) {
        $property = Get-LosAuditProperty `
            -Record $Record `
            -Name $propertyName
        if (-not [bool]$property.Exists) {
            throw "LOS audit record is missing '$propertyName'."
        }
        $resolved[$propertyName] = $property.Value
    }

    foreach ($propertyName in @(
        'ContractResolved',
        'SchemaLoaded',
        'VersionValidated',
        'SchemaValidated',
        'IntegrityVerified',
        'PreflightExecuted',
        'PostflightValidated'
    )) {
        if ($resolved[$propertyName] -isnot [bool]) {
            throw "LOS audit property '$propertyName' must be Boolean."
        }
    }

    $auditRecord = [PSCustomObject][ordered]@{
        ContractId          = [string]$resolved.ContractId
        Version             = [string]$resolved.Version
        SchemaHash          = [string]$resolved.SchemaHash
        Status              = [string]$resolved.Status
        ContractResolved    = [bool]$resolved.ContractResolved
        SchemaLoaded        = [bool]$resolved.SchemaLoaded
        VersionValidated    = [bool]$resolved.VersionValidated
        SchemaValidated     = [bool]$resolved.SchemaValidated
        IntegrityVerified   = [bool]$resolved.IntegrityVerified
        PreflightExecuted   = [bool]$resolved.PreflightExecuted
        ExecutionResult     = $resolved.ExecutionResult
        PostflightValidated = [bool]$resolved.PostflightValidated
        Error               = $resolved.Error
        AuditRecordFinalized = $true
    }

    return Invoke-EkosNormalizePipeline -InputObject $auditRecord
}

Export-ModuleMember -Function Write-LosContractAuditRecord
