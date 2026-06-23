Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Import-LosDcekModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName
    )

    $modulePath = Join-Path $PSScriptRoot ($ModuleName + '.psm1')
    if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
        throw "Required LOS-DCEK module not found: $modulePath"
    }

    $resolvedModulePath = (Resolve-Path -LiteralPath $modulePath).Path
    $module = Get-Module -Name $ModuleName |
        Select-Object -First 1
    if ($null -ne $module) {
        if (-not [System.StringComparer]::OrdinalIgnoreCase.Equals(
            [System.IO.Path]::GetFullPath($module.Path),
            [System.IO.Path]::GetFullPath($resolvedModulePath)
        )) {
            throw "Unauthorized LOS-DCEK module path for '$ModuleName'."
        }
        return $module
    }

    Import-Module $resolvedModulePath -ErrorAction Stop
    $module = Get-Module -Name $ModuleName |
        Select-Object -First 1
    if ($null -eq $module) {
        throw "Required LOS-DCEK module failed to load: $ModuleName"
    }

    return $module
}

$script:RuntimeModule = Import-LosDcekModule `
    -ModuleName 'EKOS.GraphRuntime'
$script:IntegrityModule = Import-LosDcekModule `
    -ModuleName 'LOS.ContractIntegrityGuard'
$script:ContractSystemModule = Import-LosDcekModule `
    -ModuleName 'LOS.ContractSystem'
$script:AuditModule = Import-LosDcekModule `
    -ModuleName 'LOS.AuditLayer'

function Get-LosDcekCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.PSModuleInfo]$Module,

        [Parameter(Mandatory)]
        [string]$CommandName
    )

    if (-not $Module.ExportedCommands.ContainsKey($CommandName)) {
        throw "LOS-DCEK module '$($Module.Name)' must export '$CommandName'."
    }

    return $Module.ExportedCommands[$CommandName]
}

function ConvertTo-LosBrokerError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $canonical = & $script:RuntimeModule {
        param($Record)
        ConvertTo-EkosCanonicalError -ErrorRecord $Record
    } $ErrorRecord

    return [PSCustomObject][ordered]@{
        Type     = [string]$canonical.Type
        Message  = [string]$canonical.Message
        Category = [string]$canonical.Category
        Target   = [string]$canonical.Target
    }
}

function ConvertTo-LosContextHashtable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Context
    )

    $result = @{}
    if ($null -eq $Context) {
        return $result
    }

    if ($Context -is [System.Collections.IDictionary]) {
        foreach ($entry in $Context.GetEnumerator()) {
            $result[[string]$entry.Key] = $entry.Value
        }
        return $result
    }

    foreach ($property in $Context.PSObject.Properties) {
        if ($property.MemberType -in @(
            'Property',
            'NoteProperty',
            'AliasProperty'
        )) {
            $result[$property.Name] = $property.Value
        }
    }

    return $result
}

function Get-LosBrokerCallerModule {
    [CmdletBinding()]
    param()

    foreach ($frame in Get-PSCallStack) {
        $module = $frame.InvocationInfo.MyCommand.Module
        if ($null -eq $module) {
            continue
        }

        if (-not [System.StringComparer]::Ordinal.Equals(
            [string]$module.Name,
            'LOS.ContractRuntimeBroker'
        )) {
            return $module
        }
    }

    return $null
}

function Invoke-ContractedExecution {
    <#
    .SYNOPSIS
    Executes an EKOS request through the LOS-DCEK v1 syscall boundary.

    .DESCRIPTION
    Resolves and attests the requested schema through the integrity guard,
    invokes the guarded contract enforcement kernel, finalizes the one-use
    attestation, emits the complete deterministic audit trace, and returns the
    normalized execution result.

    .PARAMETER ContractId
    Exact ordinal contract identifier registered by LOS.ContractSchemaRegistry.

    .PARAMETER Version
    Exact semantic contract version in MAJOR.MINOR.PATCH form.

    .PARAMETER Operation
    EKOS operation script block. It receives a Context parameter containing
    normalized Context, Contract, and Request values.

    .PARAMETER Request
    Contract request object.

    .PARAMETER Context
    Execution context hashtable.

    .OUTPUTS
    PSCustomObject
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ContractId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Version,

        [Parameter(Mandatory)]
        [scriptblock]$Operation,

        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Request,

        [Parameter(Mandatory)]
        [AllowNull()]
        [hashtable]$Context
    )

    $normalizeCommand = Get-LosDcekCommand `
        -Module $script:RuntimeModule `
        -CommandName 'Invoke-EkosNormalizePipeline'
    $runtimeInfoCommand = Get-LosDcekCommand `
        -Module $script:RuntimeModule `
        -CommandName 'Get-EkosRuntimeInfo'
    $integrityCommand = Get-LosDcekCommand `
        -Module $script:IntegrityModule `
        -CommandName 'Invoke-IntegrityCheck'
    $kernelCommand = Get-LosDcekCommand `
        -Module $script:ContractSystemModule `
        -CommandName 'Invoke-ContractedExecution'
    $auditCommand = Get-LosDcekCommand `
        -Module $script:AuditModule `
        -CommandName 'Write-LosContractAuditRecord'

    $normalizedRequest = & $normalizeCommand -InputObject $Request
    $normalizedContextObject = & $normalizeCommand -InputObject $Context
    $normalizedContext = ConvertTo-LosContextHashtable `
        -Context $normalizedContextObject

    $status = 'Failed'
    $schemaHash = ''
    $contractResolved = $false
    $schemaLoaded = $false
    $versionValidated = $false
    $schemaValidated = $false
    $integrityVerified = $false
    $preflightExecuted = $false
    $executionResult = $null
    $postflightValidated = $false
    $kernelResult = $null
    $brokerError = $null
    $auditRecord = $null
    $attestation = $null

    try {
        $callerModule = Get-LosBrokerCallerModule
        $expectedCallerPath = Join-Path `
            $PSScriptRoot `
            'LOS.ExecutionLifecycleEnforcer.psm1'
        $callerName = if ($null -eq $callerModule) {
            ''
        }
        else {
            [string]$callerModule.Name
        }
        $callerPath = if ($null -eq $callerModule) {
            ''
        }
        else {
            [string]$callerModule.Path
        }
        $authorizedCaller = (
            [System.StringComparer]::Ordinal.Equals(
                $callerName,
                'LOS.ExecutionLifecycleEnforcer'
            ) -and
            [System.StringComparer]::OrdinalIgnoreCase.Equals(
                [System.IO.Path]::GetFullPath($callerPath),
                [System.IO.Path]::GetFullPath($expectedCallerPath)
            )
        )
        if (-not $authorizedCaller) {
            throw "LOS lifecycle violation: unauthorized broker caller '$callerName'."
        }

        $runtimeContext = & $runtimeInfoCommand
        $attestation = & $integrityCommand `
            -Phase 'Resolve' `
            -ContractId $ContractId `
            -Version $Version `
            -RuntimeContext $runtimeContext

        $schemaHash = [string]$attestation.SchemaHash
        $contractResolved = $true
        $schemaLoaded = $true
        $versionValidated = $true
        $schemaValidated = $true
        $integrityVerified = $true

        $kernelResult = & $kernelCommand `
            -IntegrityAttestation $attestation `
            -Operation $Operation `
            -Request $normalizedRequest `
            -Context $normalizedContext

        $status = [string]$kernelResult.Status
        $preflightExecuted = [bool]$kernelResult.PreflightExecuted
        $postflightValidated = [bool]$kernelResult.PostflightValidated
        $executionResult = $kernelResult.Output
        $brokerError = $kernelResult.Error
        $integrityVerified = (
            $integrityVerified -and
            [bool]$kernelResult.IntegrityVerified
        )
    }
    catch {
        $status = 'Blocked'
        $brokerError = ConvertTo-LosBrokerError -ErrorRecord $_
    }

    if ($null -ne $attestation) {
        try {
            [void](& $integrityCommand `
                -Phase 'Finalize' `
                -Attestation $attestation)
        }
        catch {
            $status = 'Failed'
            $integrityVerified = $false
            $brokerError = ConvertTo-LosBrokerError -ErrorRecord $_
        }
    }

    $auditInput = [PSCustomObject][ordered]@{
        ContractId          = $ContractId
        Version             = $Version
        SchemaHash          = $schemaHash
        Status              = $status
        ContractResolved    = $contractResolved
        SchemaLoaded        = $schemaLoaded
        VersionValidated    = $versionValidated
        SchemaValidated     = $schemaValidated
        IntegrityVerified   = $integrityVerified
        PreflightExecuted   = $preflightExecuted
        ExecutionResult     = $executionResult
        PostflightValidated = $postflightValidated
        Error               = $brokerError
    }

    try {
        $auditRecord = & $auditCommand -Record $auditInput
    }
    catch {
        $status = 'Failed'
        $brokerError = ConvertTo-LosBrokerError -ErrorRecord $_
    }

    $result = [PSCustomObject][ordered]@{
        Status     = $status
        ContractId = $ContractId
        Version    = $Version
        SchemaHash = $schemaHash
        Result     = $executionResult
        Audit      = $auditRecord
        Error      = $brokerError
    }

    return & $normalizeCommand -InputObject $result
}

Export-ModuleMember -Function Invoke-ContractedExecution
