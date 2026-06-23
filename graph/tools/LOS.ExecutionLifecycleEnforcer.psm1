Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:LifecycleAuthority = New-Object System.Object
$script:ModuleRoot = Split-Path -Parent $PSCommandPath

function Import-LosLifecycleModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,

        [Parameter()]
        [bool]$Required = $true
    )

    $modulePath = Join-Path $script:ModuleRoot ($ModuleName + '.psm1')
    if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
        if ($Required) {
            throw "Required LOS lifecycle module not found: $ModuleName"
        }
        return $null
    }

    $resolvedPath = (Resolve-Path -LiteralPath $modulePath).Path
    $module = Get-Module -Name $ModuleName | Select-Object -First 1
    if ($null -ne $module) {
        if (-not [StringComparer]::OrdinalIgnoreCase.Equals(
            [IO.Path]::GetFullPath($module.Path),
            [IO.Path]::GetFullPath($resolvedPath)
        )) {
            throw "Unauthorized LOS lifecycle module path for '$ModuleName'."
        }
        return $module
    }

    Import-Module `
        -Name $resolvedPath `
        -DisableNameChecking `
        -ErrorAction Stop
    $module = Get-Module -Name $ModuleName | Select-Object -First 1
    if ($null -eq $module) {
        throw "Required LOS lifecycle module failed to load: $ModuleName"
    }

    return $module
}

function Get-LosLifecycleCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Management.Automation.PSModuleInfo]$Module,

        [Parameter(Mandatory)]
        [string]$CommandName
    )

    if (-not $Module.ExportedCommands.ContainsKey($CommandName)) {
        throw "LOS lifecycle module '$($Module.Name)' must export '$CommandName'."
    }

    return $Module.ExportedCommands[$CommandName]
}

$script:RuntimeModule = Import-LosLifecycleModule -ModuleName 'EKOS.GraphRuntime'
$script:SerializerModule = Import-LosLifecycleModule -ModuleName 'EKOS.CanonicalSerializer'
$script:BrokerModule = Import-LosLifecycleModule -ModuleName 'LOS.ContractRuntimeBroker'
$script:IntegrityModule = Import-LosLifecycleModule -ModuleName 'LOS.ContractIntegrityGuard'
$script:RegistryModule = Import-LosLifecycleModule -ModuleName 'LOS.ContractSchemaRegistry'
$script:ContractSystemModule = Import-LosLifecycleModule -ModuleName 'LOS.ContractSystem'
$script:AuditModule = Import-LosLifecycleModule -ModuleName 'LOS.AuditLayer'

function New-LosLifecycleState {
    [CmdletBinding()]
    param()

    return [pscustomobject]@{
        Authority = $script:LifecycleAuthority
        Current   = 'PRE_FLIGHT_PENDING'
        Sequence  = 0
        Trace     = New-Object 'System.Collections.Generic.List[object]'
    }
}

function Assert-LosLifecycleState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$State,

        [Parameter(Mandatory)]
        [string]$ExpectedState
    )

    if (-not [object]::ReferenceEquals(
        $State.Authority,
        $script:LifecycleAuthority
    )) {
        throw 'LOS lifecycle violation: invalid lifecycle authority.'
    }

    if (-not [StringComparer]::Ordinal.Equals(
        [string]$State.Current,
        $ExpectedState
    )) {
        throw "LOS lifecycle violation: expected state '$ExpectedState', actual state '$($State.Current)'."
    }
}

function Add-LosLifecycleTrace {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$State,

        [Parameter(Mandatory)]
        [string]$Phase,

        [Parameter(Mandatory)]
        [string]$Outcome,

        [Parameter()]
        [string]$Detail = ''
    )

    $State.Sequence = [int]$State.Sequence + 1
    $State.Trace.Add([pscustomobject][ordered]@{
        sequence = [int]$State.Sequence
        state    = [string]$State.Current
        phase    = $Phase
        outcome  = $Outcome
        detail   = $Detail
    })
}

function Move-LosLifecycleState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$State,

        [Parameter(Mandatory)]
        [string]$TargetState
    )

    $allowedTransitions = @{
        PRE_FLIGHT_PENDING = @('PRE_FLIGHT_PASS', 'FAILED')
        PRE_FLIGHT_PASS    = @('EXECUTION_RUNNING', 'FAILED')
        EXECUTION_RUNNING  = @('POST_FLIGHT_RUNNING', 'FAILED')
        POST_FLIGHT_RUNNING = @('COMPLETED', 'FAILED')
        COMPLETED          = @()
        FAILED             = @()
    }

    $currentState = [string]$State.Current
    if (-not $allowedTransitions.ContainsKey($currentState)) {
        throw "LOS lifecycle violation: unknown state '$currentState'."
    }

    $isAllowed = $false
    foreach ($allowedTarget in @($allowedTransitions[$currentState])) {
        if ([StringComparer]::Ordinal.Equals(
            [string]$allowedTarget,
            $TargetState
        )) {
            $isAllowed = $true
            break
        }
    }

    if (-not $isAllowed) {
        throw "LOS lifecycle violation: invalid transition '$currentState' to '$TargetState'."
    }

    $State.Current = $TargetState
}

function ConvertTo-LosLifecycleHashtable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$InputObject
    )

    $result = @{}
    if ($null -eq $InputObject) {
        return $result
    }

    if ($InputObject -is [Collections.IDictionary]) {
        foreach ($entry in $InputObject.GetEnumerator()) {
            $result[[string]$entry.Key] = $entry.Value
        }
        return $result
    }

    foreach ($property in $InputObject.PSObject.Properties) {
        if ($property.MemberType -in @(
            'Property',
            'NoteProperty',
            'AliasProperty'
        )) {
            $result[[string]$property.Name] = $property.Value
        }
    }

    return $result
}

function Get-LosLifecycleValue {
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
        throw "LOS lifecycle result is missing '$Name'."
    }
    return $property.Value
}

function Get-LosLifecycleHash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$InputObject
    )

    $serializerCommand = Get-LosLifecycleCommand `
        -Module $script:SerializerModule `
        -CommandName 'ConvertTo-EkosCanonicalJson'
    $canonical = & $serializerCommand -InputObject $InputObject
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($canonical)
        $hash = $sha256.ComputeHash($bytes)
    }
    finally {
        $sha256.Dispose()
    }

    return (($hash | ForEach-Object { $_.ToString('x2') }) -join '')
}

function Write-LosLifecycleFailureAudit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ContractId,

        [Parameter(Mandatory)]
        [string]$ContractVersion,

        [Parameter(Mandatory)]
        [object]$State,

        [Parameter(Mandatory)]
        [Management.Automation.ErrorRecord]$ErrorRecord
    )

    $auditCommand = Get-LosLifecycleCommand `
        -Module $script:AuditModule `
        -CommandName 'Write-LosContractAuditRecord'

    $record = [pscustomobject][ordered]@{
        ContractId          = $ContractId
        Version             = $ContractVersion
        SchemaHash          = ''
        Status              = 'Failed'
        ContractResolved    = $false
        SchemaLoaded        = $false
        VersionValidated    = $false
        SchemaValidated     = $false
        IntegrityVerified   = $false
        PreflightExecuted   = (
            [int]$State.Sequence -gt 0
        )
        ExecutionResult     = $null
        PostflightValidated = $false
        Error               = [pscustomobject][ordered]@{
            Type     = $ErrorRecord.Exception.GetType().FullName
            Message  = $ErrorRecord.Exception.Message
            Category = [string]$ErrorRecord.CategoryInfo.Category
            Target   = [string]$ErrorRecord.TargetObject
        }
    }

    return & $auditCommand -Record $record
}

function Invoke-PREFlightCheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$State,

        [Parameter(Mandatory)]
        [string]$ContractId,

        [Parameter(Mandatory)]
        [string]$ContractVersion
    )

    Assert-LosLifecycleState `
        -State $State `
        -ExpectedState 'PRE_FLIGHT_PENDING'
    Add-LosLifecycleTrace `
        -State $State `
        -Phase 'PRE_FLIGHT' `
        -Outcome 'STARTED'

    [void](Get-LosLifecycleCommand `
        -Module $script:BrokerModule `
        -CommandName 'Invoke-ContractedExecution')
    [void](Get-LosLifecycleCommand `
        -Module $script:IntegrityModule `
        -CommandName 'Invoke-IntegrityCheck')
    [void](Get-LosLifecycleCommand `
        -Module $script:ContractSystemModule `
        -CommandName 'Invoke-ContractedExecution')

    $definitionCommand = Get-LosLifecycleCommand `
        -Module $script:RegistryModule `
        -CommandName 'Get-ContractDefinition'
    $compatibilityCommand = Get-LosLifecycleCommand `
        -Module $script:RegistryModule `
        -CommandName 'Get-CompatibilityMatrix'

    $contract = & $definitionCommand `
        -ContractId $ContractId `
        -Version $ContractVersion
    $compatibility = & $compatibilityCommand `
        -ContractId $ContractId `
        -Version $ContractVersion

    if (-not [StringComparer]::Ordinal.Equals(
        [string]$contract.contractId,
        $ContractId
    ) -or
        -not [StringComparer]::Ordinal.Equals(
            [string]$contract.version,
            $ContractVersion
        )) {
        throw 'LOS lifecycle preflight failed: contract resolution mismatch.'
    }

    if (-not [bool]$compatibility.matrix.PS5 -or
        -not [bool]$compatibility.matrix.PS7) {
        throw 'LOS lifecycle preflight failed: cross-runtime compatibility is incomplete.'
    }

    Move-LosLifecycleState `
        -State $State `
        -TargetState 'PRE_FLIGHT_PASS'
    Add-LosLifecycleTrace `
        -State $State `
        -Phase 'PRE_FLIGHT' `
        -Outcome 'PASS'

    return [pscustomobject][ordered]@{
        Decision      = 'ALLOW'
        Contract      = $contract
        Compatibility = $compatibility
    }
}

function Invoke-ExecutionPhase {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$State,

        [Parameter(Mandatory)]
        [string]$ContractId,

        [Parameter(Mandatory)]
        [string]$ContractVersion,

        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$InputPayload,

        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$ExecutionContext
    )

    Assert-LosLifecycleState `
        -State $State `
        -ExpectedState 'PRE_FLIGHT_PASS'
    Move-LosLifecycleState `
        -State $State `
        -TargetState 'EXECUTION_RUNNING'
    Add-LosLifecycleTrace `
        -State $State `
        -Phase 'EXECUTION' `
        -Outcome 'STARTED'

    $normalizeCommand = Get-LosLifecycleCommand `
        -Module $script:RuntimeModule `
        -CommandName 'Invoke-EkosNormalizePipeline'
    $brokerCommand = Get-LosLifecycleCommand `
        -Module $script:BrokerModule `
        -CommandName 'Invoke-ContractedExecution'

    $normalizedPayload = & $normalizeCommand -InputObject $InputPayload
    $normalizedContextObject = & $normalizeCommand -InputObject $ExecutionContext
    $normalizedContext = ConvertTo-LosLifecycleHashtable `
        -InputObject $normalizedContextObject

    $operation = {
        param([hashtable]$Context)

        return [pscustomobject][ordered]@{
            ContractId       = [string]$Context.Contract.contractId
            ContractVersion  = [string]$Context.Contract.version
            InputPayload     = $Context.Request
            ExecutionContext = $Context.Context
        }
    }

    $brokerResult = & $brokerCommand `
        -ContractId $ContractId `
        -Version $ContractVersion `
        -Operation $operation `
        -Request $normalizedPayload `
        -Context $normalizedContext

    if (-not [StringComparer]::Ordinal.Equals(
        [string]$brokerResult.Status,
        'Completed'
    ) -or
        $null -eq $brokerResult.Audit -or
        -not [bool]$brokerResult.Audit.IntegrityVerified -or
        -not [bool]$brokerResult.Audit.PreflightExecuted -or
        -not [bool]$brokerResult.Audit.PostflightValidated -or
        -not [bool]$brokerResult.Audit.AuditRecordFinalized) {
        $message = if ($null -ne $brokerResult.Error) {
            [string]$brokerResult.Error.Message
        }
        else {
            'Contract broker did not complete the guarded execution.'
        }
        throw "LOS lifecycle execution failed: $message"
    }

    Add-LosLifecycleTrace `
        -State $State `
        -Phase 'EXECUTION' `
        -Outcome 'SUCCESS'

    return [pscustomobject][ordered]@{
        RawOutput      = $brokerResult.Result
        ExecutionAudit = $brokerResult.Audit
        SchemaHash     = [string]$brokerResult.SchemaHash
    }
}

function Invoke-POSTFlightValidation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$State,

        [Parameter(Mandatory)]
        [string]$ContractId,

        [Parameter(Mandatory)]
        [string]$ContractVersion,

        [Parameter(Mandatory)]
        [object]$PreflightResult,

        [Parameter(Mandatory)]
        [object]$ExecutionResult
    )

    Assert-LosLifecycleState `
        -State $State `
        -ExpectedState 'EXECUTION_RUNNING'
    Move-LosLifecycleState `
        -State $State `
        -TargetState 'POST_FLIGHT_RUNNING'
    Add-LosLifecycleTrace `
        -State $State `
        -Phase 'POST_FLIGHT' `
        -Outcome 'STARTED'

    $attestationModule = Import-LosLifecycleModule `
        -ModuleName 'LOS.ExecutionAttestationLayer'
    $ledgerModule = Import-LosLifecycleModule `
        -ModuleName 'LOS.ContractExecutionLedger'
    $driftModule = Import-LosLifecycleModule `
        -ModuleName 'LOS.DriftEvaluator'

    $attestationCommand = Get-LosLifecycleCommand `
        -Module $attestationModule `
        -CommandName 'New-LosExecutionAttestation'
    $ledgerCommand = Get-LosLifecycleCommand `
        -Module $ledgerModule `
        -CommandName 'Add-LosContractExecutionLedgerEntry'
    $driftCommand = Get-LosLifecycleCommand `
        -Module $driftModule `
        -CommandName 'Test-LosExecutionDrift'

    $traceSnapshot = @($State.Trace.ToArray())
    $attestationInput = [pscustomobject][ordered]@{
        ContractId      = $ContractId
        Version         = $ContractVersion
        SchemaHash      = [string]$ExecutionResult.SchemaHash
        ExecutionOutput = $ExecutionResult.RawOutput
        ExecutionTrace  = $traceSnapshot
    }
    $attestation = & $attestationCommand `
        -ExecutionRecord $attestationInput

    if ($null -eq $attestation -or
        [string]::IsNullOrEmpty(
            [string](Get-LosLifecycleValue `
                $attestation `
                'attestationId')
        ) -or
        -not [bool](Get-LosLifecycleValue $attestation 'isValid')) {
        throw 'LOS lifecycle postflight failed: execution attestation is invalid.'
    }

    $ledgerInput = [pscustomobject][ordered]@{
        ContractId   = $ContractId
        Version      = $ContractVersion
        Attestation  = $attestation
        SchemaHash   = [string]$ExecutionResult.SchemaHash
        OutputHash   = Get-LosLifecycleHash `
            -InputObject $ExecutionResult.RawOutput
    }
    $ledgerEntry = & $ledgerCommand -Entry $ledgerInput
    if ($null -eq $ledgerEntry -or
        [string]::IsNullOrEmpty(
            [string](Get-LosLifecycleValue `
                $ledgerEntry `
                'ledgerEntryId')
        ) -or
        -not [bool](Get-LosLifecycleValue $ledgerEntry 'Accepted') -or
        [bool](Get-LosLifecycleValue $ledgerEntry 'ReplayDetected')) {
        throw 'LOS lifecycle postflight failed: ledger rejected the execution.'
    }

    $driftResult = & $driftCommand `
        -ExpectedRecord $attestationInput `
        -ActualRecord ([pscustomobject][ordered]@{
            ContractId      = $ContractId
            Version         = $ContractVersion
            SchemaHash      = [string]$ExecutionResult.SchemaHash
            ExecutionOutput = $ExecutionResult.RawOutput
            ExecutionTrace  = $traceSnapshot
        })
    if ($null -eq $driftResult -or
        -not [bool]$driftResult.IsValid) {
        throw 'LOS lifecycle postflight failed: drift validation did not complete.'
    }

    $parityValidated = (
        [bool]$PreflightResult.Compatibility.matrix.PS5 -and
        [bool]$PreflightResult.Compatibility.matrix.PS7 -and
        [bool](Get-LosLifecycleValue `
            $attestation `
            'parityValidated')
    )
    if (-not $parityValidated) {
        throw 'LOS lifecycle postflight failed: PS5/PS7 parity was not validated.'
    }

    $auditCommand = Get-LosLifecycleCommand `
        -Module $script:AuditModule `
        -CommandName 'Write-LosContractAuditRecord'
    $auditRecord = & $auditCommand -Record ([pscustomobject][ordered]@{
        ContractId          = $ContractId
        Version             = $ContractVersion
        SchemaHash          = [string]$ExecutionResult.SchemaHash
        Status              = 'Completed'
        ContractResolved    = $true
        SchemaLoaded        = $true
        VersionValidated    = $true
        SchemaValidated     = $true
        IntegrityVerified   = $true
        PreflightExecuted   = $true
        ExecutionResult     = $ExecutionResult.RawOutput
        PostflightValidated = $true
        Error               = $null
    })
    if ($null -eq $auditRecord -or
        -not [bool]$auditRecord.AuditRecordFinalized) {
        throw 'LOS lifecycle postflight failed: audit finalization failed.'
    }

    $driftDetected = $false
    if ($null -ne $driftResult.PSObject.Properties['DriftDetected']) {
        $driftDetected = [bool]$driftResult.DriftDetected
    }

    Move-LosLifecycleState `
        -State $State `
        -TargetState 'COMPLETED'
    Add-LosLifecycleTrace `
        -State $State `
        -Phase 'POST_FLIGHT' `
        -Outcome $(if ($driftDetected) { 'DRIFT_DETECTED' } else { 'PASS' })

    return [pscustomobject][ordered]@{
        AttestationId  = [string](Get-LosLifecycleValue `
            $attestation `
            'attestationId')
        LedgerEntryId  = [string](Get-LosLifecycleValue `
            $ledgerEntry `
            'ledgerEntryId')
        ParityValidated = $parityValidated
        DriftDetected  = $driftDetected
    }
}

function Invoke-LifecycleExecution {
    <#
    .SYNOPSIS
    Executes a LOS-DCEK request through the enforced PRE, EXEC, POST lifecycle.

    .DESCRIPTION
    Provides the only exported lifecycle entry point. It validates contract
    resolution and execution path integrity, delegates guarded execution to
    LOS.ContractRuntimeBroker, requires complete attestation, ledger, audit,
    drift, and parity postflight validation, and fails closed on every error.

    .PARAMETER ContractId
    Exact contract identifier registered by LOS.ContractSchemaRegistry.

    .PARAMETER ContractVersion
    Exact semantic contract version.

    .PARAMETER InputPayload
    Contract input payload.

    .PARAMETER ExecutionContext
    Deterministic execution context.

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
        [string]$ContractVersion,

        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$InputPayload,

        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$ExecutionContext
    )

    $state = New-LosLifecycleState
    $preflight = 'FAIL'
    $execution = 'FAIL'
    $postflight = 'FAIL'
    $finalVerdict = 'FAILED'
    $attestationId = ''
    $ledgerEntryId = ''
    $parityValidated = $false
    $schemaHash = ''

    Add-LosLifecycleTrace `
        -State $state `
        -Phase 'LIFECYCLE' `
        -Outcome 'INITIALIZED'

    try {
        $preflightResult = Invoke-PREFlightCheck `
            -State $state `
            -ContractId $ContractId `
            -ContractVersion $ContractVersion
        $preflight = 'PASS'

        $executionResult = Invoke-ExecutionPhase `
            -State $state `
            -ContractId $ContractId `
            -ContractVersion $ContractVersion `
            -InputPayload $InputPayload `
            -ExecutionContext $ExecutionContext
        $execution = 'SUCCESS'
        $schemaHash = [string]$executionResult.SchemaHash

        $postflightResult = Invoke-POSTFlightValidation `
            -State $state `
            -ContractId $ContractId `
            -ContractVersion $ContractVersion `
            -PreflightResult $preflightResult `
            -ExecutionResult $executionResult
        $postflight = 'PASS'
        $attestationId = [string]$postflightResult.AttestationId
        $ledgerEntryId = [string]$postflightResult.LedgerEntryId
        $parityValidated = [bool]$postflightResult.ParityValidated
        $finalVerdict = if ([bool]$postflightResult.DriftDetected) {
            'DRIFT_DETECTED'
        }
        else {
            'CERTIFIED'
        }
    }
    catch {
        if (-not [StringComparer]::Ordinal.Equals(
            [string]$state.Current,
            'FAILED'
        ) -and
            -not [StringComparer]::Ordinal.Equals(
                [string]$state.Current,
                'COMPLETED'
            )) {
            Move-LosLifecycleState `
                -State $state `
                -TargetState 'FAILED'
        }

        Add-LosLifecycleTrace `
            -State $state `
            -Phase 'LIFECYCLE' `
            -Outcome 'HARD_BLOCK' `
            -Detail $_.Exception.Message

        try {
            [void](Write-LosLifecycleFailureAudit `
                -ContractId $ContractId `
                -ContractVersion $ContractVersion `
                -State $state `
                -ErrorRecord $_)
            Add-LosLifecycleTrace `
                -State $state `
                -Phase 'AUDIT' `
                -Outcome 'FAILURE_RECORDED'
        }
        catch {
            Add-LosLifecycleTrace `
                -State $state `
                -Phase 'AUDIT' `
                -Outcome 'FAILURE_RECORD_BLOCKED'
        }
    }

    return [pscustomobject][ordered]@{
        contractId       = $ContractId
        version          = $ContractVersion
        preflight        = $preflight
        execution        = $execution
        postflight       = $postflight
        finalVerdict     = $finalVerdict
        schemaHash       = $schemaHash
        executionTrace   = @($state.Trace.ToArray())
        attestationId    = $attestationId
        ledgerEntryId    = $ledgerEntryId
        parityValidated  = $parityValidated
    }
}

Export-ModuleMember -Function Invoke-LifecycleExecution
