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

function Get-LosCanonicalRuntimeContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$RuntimeContext
    )

    function Get-LosRuntimeContextValue {
        param(
            [Parameter(Mandatory)]
            [AllowNull()]
            [object]$InputObject,

            [Parameter(Mandatory)]
            [string]$Name
        )

        if ($null -eq $InputObject) {
            return $null
        }

        if ($InputObject -is [System.Collections.IDictionary]) {
            foreach ($key in $InputObject.Keys) {
                if ([System.StringComparer]::Ordinal.Equals(
                    [string]$key,
                    $Name
                )) {
                    return $InputObject[$key]
                }
            }

            return $null
        }

        $property = $InputObject.PSObject.Properties[$Name]
        if ($null -eq $property) {
            return $null
        }

        return $property.Value
    }

    $runtime = ''
    $runtimeValue = Get-LosRuntimeContextValue `
        -InputObject $RuntimeContext `
        -Name 'Runtime'
    if ($null -ne $runtimeValue) {
        $runtime = [string]$runtimeValue
    }

    if ([string]::IsNullOrEmpty($runtime)) {
        $editionValue = Get-LosRuntimeContextValue `
            -InputObject $RuntimeContext `
            -Name 'Edition'
        if ($null -ne $editionValue) {
            $edition = [string]$editionValue
            if ([System.StringComparer]::Ordinal.Equals($edition, 'Desktop')) {
                $runtime = 'PS5'
            }
            elseif ([System.StringComparer]::Ordinal.Equals($edition, 'Core')) {
                $runtime = 'PS7'
            }
        }
    }

    if ([string]::IsNullOrEmpty($runtime)) {
        $versionValue = Get-LosRuntimeContextValue `
            -InputObject $RuntimeContext `
            -Name 'PSVersion'
        if ($null -ne $versionValue) {
            $version = [version]([string]$versionValue)
            if ($version.Major -eq 5) {
                $runtime = 'PS5'
            }
            elseif ($version.Major -ge 7) {
                $runtime = 'PS7'
            }
        }
    }

    if ([System.StringComparer]::Ordinal.Equals($runtime, 'PS5')) {
        return [PSCustomObject][ordered]@{
            Runtime   = 'PS5'
            Edition   = 'Desktop'
            PSVersion = '5.1'
        }
    }

    if ([System.StringComparer]::Ordinal.Equals($runtime, 'PS7')) {
        return [PSCustomObject][ordered]@{
            Runtime   = 'PS7'
            Edition   = 'Core'
            PSVersion = '7.0'
        }
    }

    throw 'LOS runtime context cannot be normalized to PS5 or PS7.'
}

function Resolve-LosBrokerPath {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowEmptyString()]
        [string]$Path
    )

    if ([string]::IsNullOrEmpty($Path)) {
        return ''
    }

    try {
        return [System.IO.Path]::GetFullPath($Path)
    }
    catch {
        return ''
    }
}

function Get-LosBrokerStackFrameValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($null -eq $InputObject) {
        return $null
    }

    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

function Test-LosBrokerAuthorizedCaller {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ExpectedCallerPath
    )

    $expectedPath = Resolve-LosBrokerPath -Path $ExpectedCallerPath
    $expectedName = 'LOS.ExecutionLifecycleEnforcer'
    $brokerPath = Resolve-LosBrokerPath -Path $PSCommandPath
    $lastCallerName = ''
    $lastCallerPath = ''

    foreach ($frame in Get-PSCallStack) {
        $invocation = Get-LosBrokerStackFrameValue `
            -InputObject $frame `
            -Name 'InvocationInfo'
        $command = if ($null -eq $invocation) {
            $null
        }
        else {
            Get-LosBrokerStackFrameValue `
                -InputObject $invocation `
                -Name 'MyCommand'
        }
        $module = if ($null -eq $command) {
            $null
        }
        else {
            Get-LosBrokerStackFrameValue `
                -InputObject $command `
                -Name 'Module'
        }

        $moduleName = ''
        if ($null -ne $module) {
            $moduleName = [string](Get-LosBrokerStackFrameValue `
                -InputObject $module `
                -Name 'Name')
        }
        if ([string]::IsNullOrEmpty($moduleName) -and $null -ne $command) {
            $moduleName = [string](Get-LosBrokerStackFrameValue `
                -InputObject $command `
                -Name 'ModuleName')
        }

        $candidatePaths = New-Object 'System.Collections.Generic.List[string]'
        if ($null -ne $module) {
            $candidatePaths.Add([string](Get-LosBrokerStackFrameValue `
                -InputObject $module `
                -Name 'Path'))
        }
        $candidatePaths.Add([string](Get-LosBrokerStackFrameValue `
            -InputObject $frame `
            -Name 'ScriptName'))
        if ($null -ne $invocation) {
            $candidatePaths.Add([string](Get-LosBrokerStackFrameValue `
                -InputObject $invocation `
                -Name 'ScriptName'))
            $candidatePaths.Add([string](Get-LosBrokerStackFrameValue `
                -InputObject $invocation `
                -Name 'PSCommandPath'))
        }
        if ($null -ne $command) {
            $scriptBlock = Get-LosBrokerStackFrameValue `
                -InputObject $command `
                -Name 'ScriptBlock'
            if ($null -ne $scriptBlock) {
                $candidatePaths.Add([string](Get-LosBrokerStackFrameValue `
                    -InputObject $scriptBlock `
                    -Name 'File'))
            }
        }

        foreach ($candidatePath in $candidatePaths) {
            $resolvedPath = Resolve-LosBrokerPath -Path $candidatePath
            if ([string]::IsNullOrEmpty($resolvedPath)) {
                continue
            }

            if ([System.StringComparer]::OrdinalIgnoreCase.Equals(
                $resolvedPath,
                $brokerPath
            )) {
                continue
            }

            $lastCallerName = $moduleName
            $lastCallerPath = $resolvedPath

            if (-not [System.StringComparer]::OrdinalIgnoreCase.Equals(
                $resolvedPath,
                $expectedPath
            )) {
                continue
            }

            if ([string]::IsNullOrEmpty($moduleName) -or
                [System.StringComparer]::Ordinal.Equals(
                    $moduleName,
                    $expectedName
                ) -or
                [System.StringComparer]::OrdinalIgnoreCase.Equals(
                    [System.IO.Path]::GetFileNameWithoutExtension($resolvedPath),
                    $expectedName
                )) {
                return [PSCustomObject][ordered]@{
                    Authorized = $true
                    CallerName = $expectedName
                    CallerPath = $resolvedPath
                }
            }
        }
    }

    return [PSCustomObject][ordered]@{
        Authorized = $false
        CallerName = $lastCallerName
        CallerPath = $lastCallerPath
    }
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
        $expectedCallerPath = Join-Path `
            $PSScriptRoot `
            'LOS.ExecutionLifecycleEnforcer.psm1'
        $callerAuthorization = Test-LosBrokerAuthorizedCaller `
            -ExpectedCallerPath $expectedCallerPath
        if (-not [bool]$callerAuthorization.Authorized) {
            throw "LOS lifecycle violation: unauthorized broker caller '$($callerAuthorization.CallerName)'."
        }

        $runtimeContext = Get-LosCanonicalRuntimeContext `
            -RuntimeContext (& $runtimeInfoCommand)
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
