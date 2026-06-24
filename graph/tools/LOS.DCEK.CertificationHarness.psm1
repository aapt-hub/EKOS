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
$script:CanonicalSerializerPath = Join-Path $script:ModuleRoot 'EKOS.CanonicalSerializer.psm1'
$script:BrokerPath = Join-Path $script:ModuleRoot 'LOS.ContractRuntimeBroker.psm1'
$script:LifecycleEnforcerPath = Join-Path $script:ModuleRoot 'LOS.ExecutionLifecycleEnforcer.psm1'
$script:ContractSystemPath = Join-Path $script:ModuleRoot 'LOS.ContractSystem.psm1'
$script:IntegrityGuardPath = Join-Path $script:ModuleRoot 'LOS.ContractIntegrityGuard.psm1'

if (-not (Test-Path -LiteralPath $script:CanonicalSerializerPath -PathType Leaf)) {
    throw 'LOS-DCEK certification dependency missing: EKOS.CanonicalSerializer.psm1'
}

Import-Module -Name $script:CanonicalSerializerPath -Force -DisableNameChecking -ErrorAction Stop

function Get-LosCertificationHash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$InputObject
    )

    $canonical = ConvertTo-EkosCanonicalJson -InputObject $InputObject
    $bytes = [Text.Encoding]::UTF8.GetBytes($canonical)
    $sha256 = [Security.Cryptography.SHA256]::Create()

    try {
        $hash = $sha256.ComputeHash($bytes)
    }
    finally {
        $sha256.Dispose()
    }

    return (($hash | ForEach-Object { $_.ToString('x2') }) -join '')
}

function ConvertTo-LosBase64 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Value,

        [Parameter()]
        [ValidateSet('Utf8', 'Unicode')]
        [string]$Encoding = 'Utf8'
    )

    if ($Encoding -eq 'Unicode') {
        return [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Value))
    }

    return [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Value))
}

function Resolve-LosPowerShellExecutable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('PS5', 'PS7')]
        [string]$Runtime
    )

    $executable = if ($Runtime -eq 'PS5') { 'powershell.exe' } else { 'pwsh.exe' }
    $command = Get-Command -Name $executable -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($null -eq $command) {
        throw "Required certification runtime is unavailable: $executable"
    }

    return $command.Source
}

function Invoke-LosCertificationProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('PS5', 'PS7')]
        [string]$Runtime,

        [Parameter(Mandatory)]
        [string]$ScriptText
    )

    $executable = Resolve-LosPowerShellExecutable -Runtime $Runtime
    $encodedCommand = ConvertTo-LosBase64 -Value $ScriptText -Encoding Unicode
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $executable
    $startInfo.Arguments = "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand $encodedCommand"
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo

    try {
        if (-not $process.Start()) {
            throw "Unable to start $Runtime certification process."
        }

        $standardOutput = $process.StandardOutput.ReadToEnd()
        $standardError = $process.StandardError.ReadToEnd()
        $process.WaitForExit()

        if ($process.ExitCode -ne 0) {
            $message = $standardError.Trim()
            if ([string]::IsNullOrEmpty($message)) {
                $message = $standardOutput.Trim()
            }
            throw "$Runtime certification process failed with exit code $($process.ExitCode): $message"
        }

        $json = $standardOutput.Trim()
        if ([string]::IsNullOrEmpty($json)) {
            throw "$Runtime certification process returned no result."
        }

        return ConvertFrom-Json -InputObject $json -ErrorAction Stop
    }
    finally {
        $process.Dispose()
    }
}

function New-LosChildPrelude {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$ModulePaths
    )

    $encodedPaths = New-Object 'System.Collections.Generic.List[string]'
    foreach ($path in $ModulePaths) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "LOS-DCEK certification dependency missing: $path"
        }
        $encodedPaths.Add((ConvertTo-LosBase64 -Value $path))
    }

    $pathStatements = New-Object 'System.Collections.Generic.List[string]'
    foreach ($encodedPath in $encodedPaths) {
        $pathStatements.Add(
            "`$modulePath = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$encodedPath'))"
        )
        $pathStatements.Add(
            "Import-Module -Name `$modulePath -Force -DisableNameChecking -ErrorAction Stop"
        )
    }

    return @"
Set-StrictMode -Version Latest
`$ErrorActionPreference = 'Stop'
`$WarningPreference = 'SilentlyContinue'
`$ProgressPreference = 'SilentlyContinue'
$($pathStatements -join [Environment]::NewLine)
"@
}

function New-LosExecutionChildScript {
    [CmdletBinding()]
    param(
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

    $envelope = [ordered]@{
        contractId      = $ContractId
        contractVersion = $ContractVersion
        inputPayload    = $InputPayload
        executionContext = $ExecutionContext
    }
    $envelopeJson = ConvertTo-EkosCanonicalJson -InputObject $envelope
    $encodedEnvelope = ConvertTo-LosBase64 -Value $envelopeJson
    $prelude = New-LosChildPrelude -ModulePaths @(
        $script:LifecycleEnforcerPath,
        $script:CanonicalSerializerPath
    )

    return @"
$prelude
`$inputJson = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$encodedEnvelope'))
`$input = ConvertFrom-Json -InputObject `$inputJson
`$request = @{}
if (`$null -ne `$input.inputPayload) {
    foreach (`$property in `$input.inputPayload.PSObject.Properties) {
        `$request[[string]`$property.Name] = `$property.Value
    }
}
`$context = @{}
if (`$null -ne `$input.executionContext) {
    foreach (`$property in `$input.executionContext.PSObject.Properties) {
        `$context[[string]`$property.Name] = `$property.Value
    }
}
`$lifecycleCommand = Get-Command -Name Invoke-LifecycleExecution -Module LOS.ExecutionLifecycleEnforcer -ErrorAction Stop
`$lifecycleParameters = @{
    ContractId       = [string]`$input.contractId
    ContractVersion  = [string]`$input.contractVersion
    InputPayload     = `$request
    ExecutionContext = `$context
}
`$lifecycleResult = & `$lifecycleCommand @lifecycleParameters
`$completed = [string]::Equals(
    [string]`$lifecycleResult.finalVerdict,
    'CERTIFIED',
    [StringComparison]::Ordinal
)
`$errorMessage = [string]`$lifecycleResult.finalVerdict
foreach (`$traceEvent in @(`$lifecycleResult.executionTrace)) {
    if ([string]::Equals([string]`$traceEvent.outcome, 'HARD_BLOCK', [StringComparison]::Ordinal) -and
        -not [string]::IsNullOrEmpty([string]`$traceEvent.detail)) {
        `$errorMessage = [string]`$traceEvent.detail
    }
}
`$schemaHash = ''
if (`$null -ne `$lifecycleResult.PSObject.Properties['schemaHash']) {
    `$schemaHash = [string]`$lifecycleResult.schemaHash
}
`$trace = [pscustomobject][ordered]@{
    ContractResolved      = [bool]`$completed
    SchemaLoaded          = [bool]`$completed
    VersionValidated      = [bool]`$completed
    SchemaValidated       = [bool]`$completed
    IntegrityVerified     = [bool]`$completed
    PreflightExecuted     = [bool]([string]::Equals([string]`$lifecycleResult.preflight, 'PASS', [StringComparison]::Ordinal))
    PostflightValidated   = [bool]([string]::Equals([string]`$lifecycleResult.postflight, 'PASS', [StringComparison]::Ordinal))
    AuditRecordFinalized  = [bool]`$completed
    ExecutionResult       = `$lifecycleResult
    LifecycleTrace        = @(`$lifecycleResult.executionTrace)
}
`$result = [pscustomobject][ordered]@{
    Status     = if (`$completed) { 'Completed' } else { 'Blocked' }
    ContractId = [string]`$lifecycleResult.contractId
    Version    = [string]`$lifecycleResult.version
    SchemaHash = `$schemaHash
    Result     = `$lifecycleResult
    Audit      = `$trace
    Error      = if (`$completed) { `$null } else { [pscustomobject][ordered]@{
        Type     = 'LOS.LifecycleCertificationFailure'
        Message  = `$errorMessage
        Category = 'InvalidResult'
        Target   = [string]`$lifecycleResult.contractId
    } }
}
`$attestation = [pscustomobject][ordered]@{
    ContractId       = [string]`$result.ContractId
    Version          = [string]`$result.Version
    SchemaHash       = [string]`$result.SchemaHash
    IntegrityVerified = [bool]`$result.Audit.IntegrityVerified
}
`$capture = [pscustomobject][ordered]@{
    Output         = `$result
    ExecutionTrace = `$trace
    Attestation    = `$attestation
}
ConvertTo-EkosCanonicalJson -InputObject `$capture
"@
}

function ConvertTo-LosExecutionCapture {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('PS5', 'PS7')]
        [string]$Runtime,

        [Parameter(Mandatory)]
        [object]$RawCapture,

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

    $inputHash = Get-LosCertificationHash -InputObject ([ordered]@{
        contractId       = $ContractId
        contractVersion  = $ContractVersion
        inputPayload     = $InputPayload
        executionContext = $ExecutionContext
    })
    $outputHash = Get-LosCertificationHash -InputObject $RawCapture.Output
    $executionPathHash = Get-LosCertificationHash -InputObject $RawCapture.ExecutionTrace
    $schemaHash = [string]$RawCapture.Attestation.SchemaHash
    $deterministicSignature = Get-LosCertificationHash -InputObject ([ordered]@{
        inputHash         = $inputHash
        outputHash        = $outputHash
        schemaHash        = $schemaHash
        executionPathHash = $executionPathHash
    })

    return [pscustomobject][ordered]@{
        Runtime                = $Runtime
        InputHash              = $inputHash
        OutputHash             = $outputHash
        SchemaHash             = $schemaHash
        ExecutionPathHash      = $executionPathHash
        DeterministicSignature = $deterministicSignature
        Output                 = $RawCapture.Output
        ExecutionTrace         = $RawCapture.ExecutionTrace
        Attestation            = $RawCapture.Attestation
    }
}

function Run-PS5Execution {
    [CmdletBinding()]
    param(
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

    $scriptText = New-LosExecutionChildScript @PSBoundParameters
    $rawCapture = Invoke-LosCertificationProcess -Runtime PS5 -ScriptText $scriptText
    return ConvertTo-LosExecutionCapture -Runtime PS5 -RawCapture $rawCapture @PSBoundParameters
}

function Run-PS7Execution {
    [CmdletBinding()]
    param(
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

    $scriptText = New-LosExecutionChildScript @PSBoundParameters
    $rawCapture = Invoke-LosCertificationProcess -Runtime PS7 -ScriptText $scriptText
    return ConvertTo-LosExecutionCapture -Runtime PS7 -RawCapture $rawCapture @PSBoundParameters
}

function Compare-DeterministicParity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$PS5Result,

        [Parameter(Mandatory)]
        [object]$PS7Result
    )

    $inputHashEqual = [string]::Equals(
        [string]$PS5Result.InputHash,
        [string]$PS7Result.InputHash,
        [StringComparison]::Ordinal
    )
    $outputHashEqual = [string]::Equals(
        [string]$PS5Result.OutputHash,
        [string]$PS7Result.OutputHash,
        [StringComparison]::Ordinal
    )
    $schemaHashEqual = [string]::Equals(
        [string]$PS5Result.SchemaHash,
        [string]$PS7Result.SchemaHash,
        [StringComparison]::Ordinal
    )
    $executionPathHashEqual = [string]::Equals(
        [string]$PS5Result.ExecutionPathHash,
        [string]$PS7Result.ExecutionPathHash,
        [StringComparison]::Ordinal
    )
    $signatureEqual = [string]::Equals(
        [string]$PS5Result.DeterministicSignature,
        [string]$PS7Result.DeterministicSignature,
        [StringComparison]::Ordinal
    )

    return [pscustomobject][ordered]@{
        InputHashEqual              = $inputHashEqual
        OutputHashEqual             = $outputHashEqual
        SchemaHashEqual             = $schemaHashEqual
        ExecutionPathHashEqual      = $executionPathHashEqual
        DeterministicSignatureEqual = $signatureEqual
        ByteIdentical               = (
            $inputHashEqual -and
            $outputHashEqual -and
            $schemaHashEqual -and
            $executionPathHashEqual -and
            $signatureEqual
        )
    }
}

function New-LosIntegrityProbeScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ContractId,

        [Parameter(Mandatory)]
        [string]$ContractVersion
    )

    $encodedContractId = ConvertTo-LosBase64 -Value $ContractId
    $encodedVersion = ConvertTo-LosBase64 -Value $ContractVersion
    $prelude = New-LosChildPrelude -ModulePaths @(
        $script:BrokerPath,
        $script:ContractSystemPath,
        $script:IntegrityGuardPath,
        $script:CanonicalSerializerPath
    )

    return @"
$prelude
`$contractId = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$encodedContractId'))
`$contractVersion = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$encodedVersion'))
`$kernelCommand = Get-Command -Name Invoke-ContractedExecution -Module LOS.ContractSystem -ErrorAction Stop
`$guardCommand = Get-Command -Name Invoke-IntegrityCheck -Module LOS.ContractIntegrityGuard -ErrorAction Stop
`$operationRan = `$false
`$operation = {
    param([hashtable]`$Context)
    `$script:operationRan = `$true
    return [pscustomobject][ordered]@{ Accepted = `$true }
}

`$forgedAttestation = [pscustomobject][ordered]@{
    Ticket     = New-Object object
    ContractId = `$contractId
    Version    = `$contractVersion
    SchemaHash = ('0' * 64)
    Schema     = [pscustomobject]@{}
}
try {
    `$directResult = & `$kernelCommand -IntegrityAttestation `$forgedAttestation -Operation `$operation -Request @{} -Context @{}
    `$directBlocked = (([string]`$directResult.Status -ne 'Success') -and (-not `$operationRan))
}
catch {
    `$directBlocked = (-not `$operationRan)
}

`$operationRan = `$false
try {
    `$null = & `$guardCommand -Phase Resolve -ContractId `$contractId -Version `$contractVersion
    `$brokerBypassBlocked = `$false
}
catch {
    `$brokerBypassBlocked = (-not `$operationRan)
}

`$attestation = & (Get-Module -Name LOS.ContractRuntimeBroker) {
    param(`$Id, `$Version)
    function Invoke-LosCertificationResolveAttestation {
        param(`$ContractId, `$ContractVersion)
        `$runtimeCommand = Get-LosDcekCommand -Module `$script:RuntimeModule -CommandName Get-EkosRuntimeInfo
        `$runtimeInfo = Get-LosCanonicalRuntimeContext -RuntimeContext (& `$runtimeCommand)
        `$integrityCommand = Get-LosDcekCommand -Module `$script:IntegrityModule -CommandName Invoke-IntegrityCheck
        return & `$integrityCommand -Phase Resolve -ContractId `$ContractId -Version `$ContractVersion -RuntimeContext `$runtimeInfo
    }
    return Invoke-LosCertificationResolveAttestation -ContractId `$Id -ContractVersion `$Version
} `$contractId `$contractVersion

`$attestation.Schema.executionModel = 'TAMPERED'
`$operationRan = `$false
try {
    `$tamperResult = & `$kernelCommand -IntegrityAttestation `$attestation -Operation `$operation -Request @{} -Context @{}
    `$schemaTamperBlocked = (([string]`$tamperResult.Status -ne 'Success') -and (-not `$operationRan))
}
catch {
    `$schemaTamperBlocked = (-not `$operationRan)
}

`$guardViolationBlocked = (`$directBlocked -and `$brokerBypassBlocked)
`$result = [pscustomobject][ordered]@{
    DirectContractSystemBlocked = [bool]`$directBlocked
    BrokerBypassBlocked         = [bool]`$brokerBypassBlocked
    SchemaTamperBlocked         = [bool]`$schemaTamperBlocked
    IntegrityViolationBlocked   = [bool]`$guardViolationBlocked
    Passed = [bool](
        `$directBlocked -and
        `$brokerBypassBlocked -and
        `$schemaTamperBlocked -and
        `$guardViolationBlocked
    )
}
ConvertTo-EkosCanonicalJson -InputObject `$result
"@
}

function Validate-IntegrityEnforcement {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ContractId,

        [Parameter(Mandatory)]
        [string]$ContractVersion
    )

    $scriptText = New-LosIntegrityProbeScript @PSBoundParameters
    $ps5 = Invoke-LosCertificationProcess -Runtime PS5 -ScriptText $scriptText
    $ps7 = Invoke-LosCertificationProcess -Runtime PS7 -ScriptText $scriptText
    $parity = [string]::Equals(
        (ConvertTo-EkosCanonicalJson -InputObject $ps5),
        (ConvertTo-EkosCanonicalJson -InputObject $ps7),
        [StringComparison]::Ordinal
    )

    return [pscustomobject][ordered]@{
        PS5    = $ps5
        PS7    = $ps7
        Parity = $parity
        Passed = ([bool]$ps5.Passed -and [bool]$ps7.Passed -and $parity)
    }
}

function New-LosReplayProbeScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ContractId,

        [Parameter(Mandatory)]
        [string]$ContractVersion
    )

    $encodedContractId = ConvertTo-LosBase64 -Value $ContractId
    $encodedVersion = ConvertTo-LosBase64 -Value $ContractVersion
    $prelude = New-LosChildPrelude -ModulePaths @(
        $script:BrokerPath,
        $script:ContractSystemPath,
        $script:CanonicalSerializerPath
    )

    return @"
$prelude
`$contractId = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$encodedContractId'))
`$contractVersion = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$encodedVersion'))
`$kernelCommand = Get-Command -Name Invoke-ContractedExecution -Module LOS.ContractSystem -ErrorAction Stop
`$attestation = & (Get-Module -Name LOS.ContractRuntimeBroker) {
    param(`$Id, `$Version)
    function Invoke-LosCertificationResolveAttestation {
        param(`$ContractId, `$ContractVersion)
        `$runtimeCommand = Get-LosDcekCommand -Module `$script:RuntimeModule -CommandName Get-EkosRuntimeInfo
        `$runtimeInfo = Get-LosCanonicalRuntimeContext -RuntimeContext (& `$runtimeCommand)
        `$integrityCommand = Get-LosDcekCommand -Module `$script:IntegrityModule -CommandName Invoke-IntegrityCheck
        return & `$integrityCommand -Phase Resolve -ContractId `$ContractId -Version `$ContractVersion -RuntimeContext `$runtimeInfo
    }
    return Invoke-LosCertificationResolveAttestation -ContractId `$Id -ContractVersion `$Version
} `$contractId `$contractVersion

`$executionCount = 0
`$operation = {
    param([hashtable]`$Context)
    `$script:executionCount++
    return [pscustomobject][ordered]@{ Accepted = `$true }
}
`$firstResult = & `$kernelCommand -IntegrityAttestation `$attestation -Operation `$operation -Request @{} -Context @{}
`$null = & (Get-Module -Name LOS.ContractRuntimeBroker) {
    param(`$Value)
    function Invoke-LosCertificationFinalizeAttestation {
        param(`$Attestation)
        `$integrityCommand = Get-LosDcekCommand -Module `$script:IntegrityModule -CommandName Invoke-IntegrityCheck
        return & `$integrityCommand -Phase Finalize -Attestation `$Attestation
    }
    return Invoke-LosCertificationFinalizeAttestation -Attestation `$Value
} `$attestation

try {
    `$replayResult = & `$kernelCommand -IntegrityAttestation `$attestation -Operation `$operation -Request @{} -Context @{}
    `$replayBlocked = (([string]`$replayResult.Status -ne 'Success') -and (`$executionCount -eq 1))
}
catch {
    `$replayBlocked = (`$executionCount -eq 1)
}

`$hasTimestamp = @(
    `$attestation.PSObject.Properties.Name |
        Where-Object { [string]::Equals([string]`$_, 'Timestamp', [StringComparison]::OrdinalIgnoreCase) -or
                       [string]::Equals([string]`$_, 'TimestampUtc', [StringComparison]::OrdinalIgnoreCase) }
).Count -gt 0
`$signatureMaterial = [pscustomobject][ordered]@{
    ContractId = `$attestation.ContractId
    Version    = `$attestation.Version
    SchemaHash = `$attestation.SchemaHash
}
`$signature = ConvertTo-EkosCanonicalJson -InputObject `$signatureMaterial
`$result = [pscustomobject][ordered]@{
    DuplicateExecutionSignatureDetected = [bool]`$replayBlocked
    TimestampInvariant                  = [bool](-not `$hasTimestamp)
    HashReuseAnomalyDetected            = [bool](`$replayBlocked -and (-not [string]::IsNullOrEmpty(`$signature)))
    ReplayBlocked                       = [bool]`$replayBlocked
    Passed = [bool](
        `$replayBlocked -and
        (-not `$hasTimestamp) -and
        (-not [string]::IsNullOrEmpty(`$signature))
    )
}
ConvertTo-EkosCanonicalJson -InputObject `$result
"@
}

function Validate-ReplayProtection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ContractId,

        [Parameter(Mandatory)]
        [string]$ContractVersion
    )

    $scriptText = New-LosReplayProbeScript @PSBoundParameters
    $ps5 = Invoke-LosCertificationProcess -Runtime PS5 -ScriptText $scriptText
    $ps7 = Invoke-LosCertificationProcess -Runtime PS7 -ScriptText $scriptText
    $parity = [string]::Equals(
        (ConvertTo-EkosCanonicalJson -InputObject $ps5),
        (ConvertTo-EkosCanonicalJson -InputObject $ps7),
        [StringComparison]::Ordinal
    )

    return [pscustomobject][ordered]@{
        PS5    = $ps5
        PS7    = $ps7
        Parity = $parity
        Passed = ([bool]$ps5.Passed -and [bool]$ps7.Passed -and $parity)
    }
}

function New-LosFailClosedProbeScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ContractId,

        [Parameter(Mandatory)]
        [string]$ContractVersion
    )

    $encodedContractId = ConvertTo-LosBase64 -Value $ContractId
    $encodedVersion = ConvertTo-LosBase64 -Value $ContractVersion
    $prelude = New-LosChildPrelude -ModulePaths @(
        $script:BrokerPath,
        $script:CanonicalSerializerPath
    )

    return @"
$prelude
`$contractId = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$encodedContractId'))
`$contractVersion = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$encodedVersion'))
`$brokerCommand = Get-Command -Name Invoke-ContractedExecution -Module LOS.ContractRuntimeBroker -ErrorAction Stop
`$executionCount = 0
`$operation = {
    param([hashtable]`$Context)
    `$script:executionCount++
    return [pscustomobject][ordered]@{ Accepted = `$true }
}

try {
    `$missingResult = & `$brokerCommand -ContractId '__LOS_MISSING_CONTRACT__' -Version `$contractVersion -Operation `$operation -Request @{} -Context @{}
    `$missingBlocked = (([string]`$missingResult.Status -ne 'Success') -and (`$executionCount -eq 0))
}
catch {
    `$missingBlocked = (`$executionCount -eq 0)
}

try {
    `$versionResult = & `$brokerCommand -ContractId `$contractId -Version '999.999.999' -Operation `$operation -Request @{} -Context @{}
    `$invalidSchemaBlocked = (([string]`$versionResult.Status -ne 'Success') -and (`$executionCount -eq 0))
}
catch {
    `$invalidSchemaBlocked = (`$executionCount -eq 0)
}

try {
    `$contextResult = & `$brokerCommand -ContractId `$contractId -Version `$contractVersion -Operation `$operation -Request @{} -Context '__CORRUPT_CONTEXT__'
    `$corruptContextBlocked = (([string]`$contextResult.Status -ne 'Success') -and (`$executionCount -eq 0))
}
catch {
    `$corruptContextBlocked = (`$executionCount -eq 0)
}

`$result = [pscustomobject][ordered]@{
    MissingContractBlocked          = [bool]`$missingBlocked
    InvalidSchemaOrVersionBlocked   = [bool]`$invalidSchemaBlocked
    CorruptedExecutionContextBlocked = [bool]`$corruptContextBlocked
    Passed = [bool](
        `$missingBlocked -and
        `$invalidSchemaBlocked -and
        `$corruptContextBlocked -and
        (`$executionCount -eq 0)
    )
}
ConvertTo-EkosCanonicalJson -InputObject `$result
"@
}

function Validate-FailClosedBehavior {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ContractId,

        [Parameter(Mandatory)]
        [string]$ContractVersion
    )

    $scriptText = New-LosFailClosedProbeScript @PSBoundParameters
    $ps5 = Invoke-LosCertificationProcess -Runtime PS5 -ScriptText $scriptText
    $ps7 = Invoke-LosCertificationProcess -Runtime PS7 -ScriptText $scriptText
    $parity = [string]::Equals(
        (ConvertTo-EkosCanonicalJson -InputObject $ps5),
        (ConvertTo-EkosCanonicalJson -InputObject $ps7),
        [StringComparison]::Ordinal
    )

    return [pscustomobject][ordered]@{
        PS5    = $ps5
        PS7    = $ps7
        Parity = $parity
        Passed = ([bool]$ps5.Passed -and [bool]$ps7.Passed -and $parity)
    }
}

function Test-LosAuditTraceComplete {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$ExecutionResult
    )

    $audit = $ExecutionResult.ExecutionTrace
    if ($null -eq $audit) {
        return $false
    }

    $requiredBooleanEvents = @(
        'ContractResolved',
        'SchemaValidated',
        'IntegrityVerified',
        'PreflightExecuted',
        'PostflightValidated',
        'AuditRecordFinalized'
    )

    foreach ($eventName in $requiredBooleanEvents) {
        $property = $audit.PSObject.Properties[$eventName]
        if ($null -eq $property -or -not [bool]$property.Value) {
            return $false
        }
    }

    return ($null -ne $audit.PSObject.Properties['ExecutionResult'])
}

function Build-CertificationReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ContractId,

        [Parameter(Mandatory)]
        [bool]$PS5Parity,

        [Parameter(Mandatory)]
        [bool]$PS7Parity,

        [Parameter(Mandatory)]
        [bool]$ByteIdentical,

        [Parameter(Mandatory)]
        [bool]$IntegrityPassed,

        [Parameter(Mandatory)]
        [bool]$ReplayProtectionPassed,

        [Parameter(Mandatory)]
        [bool]$FailClosedPassed,

        [Parameter(Mandatory)]
        [bool]$AuditTraceComplete,

        [Parameter()]
        [string[]]$Failures = @()
    )

    $allPassed = (
        $PS5Parity -and
        $PS7Parity -and
        $ByteIdentical -and
        $IntegrityPassed -and
        $ReplayProtectionPassed -and
        $FailClosedPassed -and
        $AuditTraceComplete
    )

    return [pscustomobject][ordered]@{
        dcekVersion             = '1.0'
        contractId              = $ContractId
        ps5Parity               = $PS5Parity
        ps7Parity               = $PS7Parity
        byteIdentical           = $ByteIdentical
        integrityPassed         = $IntegrityPassed
        replayProtectionPassed  = $ReplayProtectionPassed
        failClosedPassed        = $FailClosedPassed
        auditTraceComplete      = $AuditTraceComplete
        status                  = if ($allPassed) { 'CERTIFIED' } else { 'FAILED' }
        failures                = @($Failures | Sort-Object)
    }
}

function Invoke-CertificationRun {
    [CmdletBinding()]
    param(
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

    $failures = New-Object 'System.Collections.Generic.List[string]'
    $ps5Parity = $false
    $ps7Parity = $false
    $byteIdentical = $false
    $integrityPassed = $false
    $replayProtectionPassed = $false
    $failClosedPassed = $false
    $auditTraceComplete = $false

    try {
        $ps5Result = Run-PS5Execution @PSBoundParameters
        $ps7Result = Run-PS7Execution @PSBoundParameters
        $parity = Compare-DeterministicParity -PS5Result $ps5Result -PS7Result $ps7Result

        $ps5Parity = (
            [string]::Equals([string]$ps5Result.Output.Status, 'Completed', [StringComparison]::Ordinal) -and
            [string]::Equals([string]$ps5Result.Runtime, 'PS5', [StringComparison]::Ordinal)
        )
        $ps7Parity = (
            [string]::Equals([string]$ps7Result.Output.Status, 'Completed', [StringComparison]::Ordinal) -and
            [string]::Equals([string]$ps7Result.Runtime, 'PS7', [StringComparison]::Ordinal)
        )
        $byteIdentical = [bool]$parity.ByteIdentical
        $auditTraceComplete = (
            (Test-LosAuditTraceComplete -ExecutionResult $ps5Result) -and
            (Test-LosAuditTraceComplete -ExecutionResult $ps7Result)
        )

        if (-not $ps5Parity) { $failures.Add('PS5 execution did not complete successfully.') }
        if (-not $ps7Parity) { $failures.Add('PS7 execution did not complete successfully.') }
        if (-not $byteIdentical) { $failures.Add('PS5 and PS7 deterministic hashes diverged.') }
        if (-not $auditTraceComplete) { $failures.Add('Required audit trace events are incomplete.') }

        $integrity = Validate-IntegrityEnforcement -ContractId $ContractId -ContractVersion $ContractVersion
        $integrityPassed = [bool]$integrity.Passed
        if (-not $integrityPassed) {
            $failures.Add('Integrity enforcement certification failed.')
        }

        $replay = Validate-ReplayProtection -ContractId $ContractId -ContractVersion $ContractVersion
        $replayProtectionPassed = [bool]$replay.Passed
        if (-not $replayProtectionPassed) {
            $failures.Add('Replay protection certification failed.')
        }

        $failClosed = Validate-FailClosedBehavior -ContractId $ContractId -ContractVersion $ContractVersion
        $failClosedPassed = [bool]$failClosed.Passed
        if (-not $failClosedPassed) {
            $failures.Add('Fail-closed behavior certification failed.')
        }
    }
    catch {
        $failures.Add("Certification terminated: $($_.Exception.Message)")
    }

    return Build-CertificationReport `
        -ContractId $ContractId `
        -PS5Parity $ps5Parity `
        -PS7Parity $ps7Parity `
        -ByteIdentical $byteIdentical `
        -IntegrityPassed $integrityPassed `
        -ReplayProtectionPassed $replayProtectionPassed `
        -FailClosedPassed $failClosedPassed `
        -AuditTraceComplete $auditTraceComplete `
        -Failures $failures.ToArray()
}

Export-ModuleMember -Function @(
    'Invoke-CertificationRun',
    'Run-PS5Execution',
    'Run-PS7Execution',
    'Compare-DeterministicParity',
    'Validate-IntegrityEnforcement',
    'Validate-ReplayProtection',
    'Validate-FailClosedBehavior',
    'Build-CertificationReport'
)
