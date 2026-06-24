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

$serializerPath = Join-Path $PSScriptRoot 'EKOS.CanonicalSerializer.psm1'
$registryPath = Join-Path $PSScriptRoot 'LOS.ContractSchemaRegistry.psm1'

function Import-LosIntegrityDependency {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,

        [Parameter(Mandatory)]
        [string]$ModulePath
    )

    $resolvedPath = (Resolve-Path -LiteralPath $ModulePath).Path
    $module = Get-Module -Name $ModuleName |
        Select-Object -First 1
    if ($null -ne $module) {
        if (-not [System.StringComparer]::OrdinalIgnoreCase.Equals(
            [System.IO.Path]::GetFullPath($module.Path),
            [System.IO.Path]::GetFullPath($resolvedPath)
        )) {
            throw "Unauthorized LOS integrity dependency path for '$ModuleName'."
        }
        return
    }

    Import-Module $resolvedPath -ErrorAction Stop
}

Import-LosIntegrityDependency `
    -ModuleName 'EKOS.CanonicalSerializer' `
    -ModulePath $serializerPath
Import-LosIntegrityDependency `
    -ModuleName 'LOS.ContractSchemaRegistry' `
    -ModulePath $registryPath

$script:IssuedAttestations = New-Object `
    'System.Collections.Generic.Dictionary[object,object]'

function Get-LosCallerModuleName {
    [CmdletBinding()]
    param()

    foreach ($frame in Get-PSCallStack) {
        $moduleName = [string]$frame.InvocationInfo.MyCommand.ModuleName
        if ([string]::IsNullOrEmpty($moduleName)) {
            continue
        }

        if (-not [System.StringComparer]::Ordinal.Equals(
            $moduleName,
            'LOS.ContractIntegrityGuard'
        )) {
            return $moduleName
        }
    }

    return ''
}

function Assert-LosAuthorizedCaller {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ExpectedModule
    )

    $caller = Get-LosCallerModuleName
    if (-not [System.StringComparer]::Ordinal.Equals(
        $caller,
        $ExpectedModule
    )) {
        throw "LOS integrity violation: unauthorized caller '$caller'."
    }
}

function Get-LosSchemaHash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Schema
    )

    $canonicalJson = ConvertTo-EkosCanonicalJson -InputObject $Schema
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($canonicalJson)
        $hash = $sha256.ComputeHash($bytes)
    }
    finally {
        $sha256.Dispose()
    }

    return (
        [System.BitConverter]::ToString($hash) -replace '-', ''
    ).ToLowerInvariant()
}

function Get-LosAttestationState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Attestation
    )

    $ticketProperty = $Attestation.PSObject.Properties['Ticket']
    if ($null -eq $ticketProperty -or $null -eq $ticketProperty.Value) {
        throw 'LOS integrity violation: attestation ticket is missing.'
    }

    $ticket = $ticketProperty.Value
    if (-not $script:IssuedAttestations.ContainsKey($ticket)) {
        throw 'LOS integrity violation: attestation is unknown or cached.'
    }

    return $script:IssuedAttestations[$ticket]
}

function Assert-LosAttestationIntegrity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Attestation,

        [Parameter(Mandatory)]
        [object]$State
    )

    foreach ($propertyName in @(
        'ContractId',
        'Version',
        'SchemaHash',
        'Schema'
    )) {
        if ($null -eq $Attestation.PSObject.Properties[$propertyName]) {
            throw "LOS integrity violation: attestation property '$propertyName' is missing."
        }
    }

    if (-not [System.StringComparer]::Ordinal.Equals(
        [string]$Attestation.ContractId,
        [string]$State.ContractId
    )) {
        throw 'LOS integrity violation: contract identifier mismatch.'
    }

    if (-not [System.StringComparer]::Ordinal.Equals(
        [string]$Attestation.Version,
        [string]$State.Version
    )) {
        throw 'LOS integrity violation: contract version mismatch.'
    }

    $actualHash = Get-LosSchemaHash -Schema $Attestation.Schema
    if (-not [System.StringComparer]::Ordinal.Equals(
        $actualHash,
        [string]$State.SchemaHash
    ) -or
        -not [System.StringComparer]::Ordinal.Equals(
            [string]$Attestation.SchemaHash,
            [string]$State.SchemaHash
        )) {
        throw 'LOS integrity violation: contract schema hash mismatch.'
    }
}

function Invoke-IntegrityCheck {
    [CmdletBinding(DefaultParameterSetName = 'Resolve')]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Resolve', 'PreFlight', 'PostFlight', 'Finalize')]
        [string]$Phase,

        [Parameter(Mandatory, ParameterSetName = 'Resolve')]
        [ValidateNotNullOrEmpty()]
        [string]$ContractId,

        [Parameter(Mandatory, ParameterSetName = 'Resolve')]
        [ValidateNotNullOrEmpty()]
        [string]$Version,

        [Parameter(Mandatory, ParameterSetName = 'Resolve')]
        [object]$RuntimeContext,

        [Parameter(Mandatory, ParameterSetName = 'Attestation')]
        [object]$Attestation
    )

    if ($Phase -ceq 'Resolve') {
        Assert-LosAuthorizedCaller `
            -ExpectedModule 'LOS.ContractRuntimeBroker'

        $schema = Resolve-ContractSchema `
            -ContractId $ContractId `
            -Version $Version `
            -RuntimeContext $RuntimeContext
        foreach ($auditProperty in @(
            'ContractResolved',
            'SchemaLoaded',
            'VersionValidated'
        )) {
            if ($null -eq $schema.resolutionAudit.PSObject.Properties[$auditProperty] -or
                -not [bool]$schema.resolutionAudit.$auditProperty) {
                throw "LOS integrity violation: registry proof '$auditProperty' is missing."
            }
        }

        $schemaHash = Get-LosSchemaHash -Schema $schema
        $ticket = New-Object System.Object

        $state = [PSCustomObject]@{
            ContractId = $ContractId
            Version    = $Version
            SchemaHash = $schemaHash
            Stage      = 'Issued'
        }
        $script:IssuedAttestations.Add($ticket, $state)

        return [PSCustomObject][ordered]@{
            ContractId = $ContractId
            Version    = $Version
            SchemaHash = $schemaHash
            Schema     = $schema
            Ticket     = $ticket
        }
    }

    $expectedCaller = if ($Phase -ceq 'Finalize') {
        'LOS.ContractRuntimeBroker'
    }
    else {
        'LOS.ContractSystem'
    }
    Assert-LosAuthorizedCaller -ExpectedModule $expectedCaller

    $state = Get-LosAttestationState -Attestation $Attestation
    Assert-LosAttestationIntegrity `
        -Attestation $Attestation `
        -State $state

    if ($Phase -ceq 'PreFlight') {
        if ($state.Stage -cne 'Issued') {
            throw "LOS integrity violation: invalid preflight stage '$($state.Stage)'."
        }
        $state.Stage = 'PreFlightVerified'
    }
    elseif ($Phase -ceq 'PostFlight') {
        if ($state.Stage -cne 'PreFlightVerified') {
            throw "LOS integrity violation: invalid postflight stage '$($state.Stage)'."
        }
        $state.Stage = 'PostFlightVerified'
    }
    else {
        if ($state.Stage -ceq 'Consumed') {
            throw 'LOS integrity violation: attestation has already been consumed.'
        }
        $state.Stage = 'Consumed'
        [void]$script:IssuedAttestations.Remove($Attestation.Ticket)
    }

    return [PSCustomObject][ordered]@{
        ContractId       = $state.ContractId
        Version          = $state.Version
        SchemaHash       = $state.SchemaHash
        IntegrityVerified = $true
        Stage            = $state.Stage
    }
}

Export-ModuleMember -Function Invoke-IntegrityCheck
