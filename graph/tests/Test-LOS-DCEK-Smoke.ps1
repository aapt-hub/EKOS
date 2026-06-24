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
$WarningPreference = 'SilentlyContinue'

$script:Results = New-Object 'System.Collections.Generic.List[object]'

function Add-SmokeResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('PASS', 'FAIL', 'SKIP')]
        [string]$Status,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [AllowEmptyString()]
        [string]$Detail = ''
    )

    $script:Results.Add([pscustomobject][ordered]@{
        Status = $Status
        Name   = $Name
        Detail = $Detail
    })
}

function Invoke-SmokeCheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    try {
        $detail = & $ScriptBlock
        if ($null -eq $detail) {
            $detail = ''
        }
        Add-SmokeResult -Status PASS -Name $Name -Detail ([string]$detail)
    }
    catch {
        Add-SmokeResult -Status FAIL -Name $Name -Detail $_.Exception.Message
    }
}

function Assert-Smoke {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [bool]$Condition,

        [Parameter(Mandatory)]
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Get-SmokeRepositoryRoot {
    [CmdletBinding()]
    param()

    $scriptPath = if ([string]::IsNullOrEmpty($PSScriptRoot)) {
        Split-Path -Parent $MyInvocation.MyCommand.Path
    }
    else {
        $PSScriptRoot
    }

    return (Resolve-Path -LiteralPath (Join-Path $scriptPath '..\..')).Path
}

function Import-SmokeModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    Import-Module `
        -Name $Path `
        -Force `
        -DisableNameChecking `
        -ErrorAction Stop
}

function Reset-SmokeModules {
    [CmdletBinding()]
    param()

    Get-Module |
        Where-Object {
            [string]$_.Name -like 'LOS.*' -or
            [string]::Equals(
                [string]$_.Name,
                'EKOS.GraphRuntime',
                [StringComparison]::Ordinal
            ) -or
            [string]::Equals(
                [string]$_.Name,
                'EKOS.CanonicalSerializer',
                [StringComparison]::Ordinal
            )
        } |
        Remove-Module -Force
}

function Test-SmokePs7EnvironmentSkip {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    if ($Message.IndexOf(
        'Required certification runtime is unavailable: pwsh.exe',
        [StringComparison]::Ordinal
    ) -ge 0) {
        return $true
    }

    if ($Message.IndexOf(
        'The file cannot be accessed by the system',
        [StringComparison]::Ordinal
    ) -ge 0) {
        return $true
    }

    if ($Message.IndexOf(
        'Unable to start PS7 certification process',
        [StringComparison]::Ordinal
    ) -ge 0) {
        return $true
    }

    return $false
}

function Get-SmokeLifecycleFailureDetail {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$LifecycleResult
    )

    if ($null -eq $LifecycleResult) {
        return ''
    }

    foreach ($traceEvent in @($LifecycleResult.executionTrace)) {
        if ([string]::Equals(
            [string]$traceEvent.outcome,
            'HARD_BLOCK',
            [StringComparison]::Ordinal
        ) -and
            -not [string]::IsNullOrEmpty([string]$traceEvent.detail)) {
            return [string]$traceEvent.detail
        }
    }

    return ''
}

function Get-SmokeExecutionFailureDetail {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$ExecutionResult
    )

    if ($null -eq $ExecutionResult) {
        return ''
    }

    if ($null -ne $ExecutionResult.Output -and
        $null -ne $ExecutionResult.Output.Error -and
        $null -ne $ExecutionResult.Output.Error.PSObject.Properties['Message']) {
        return [string]$ExecutionResult.Output.Error.Message
    }

    if ($null -ne $ExecutionResult.Output -and
        $null -ne $ExecutionResult.Output.Result) {
        return Get-SmokeLifecycleFailureDetail `
            -LifecycleResult $ExecutionResult.Output.Result
    }

    return ''
}

$repoRoot = Get-SmokeRepositoryRoot
$toolsRoot = Join-Path $repoRoot 'graph\tools'

$requiredModules = @(
    'EKOS.CanonicalSerializer.psm1',
    'EKOS.GraphRuntime.psm1',
    'LOS.ContractSchemaRegistry.psm1',
    'LOS.ContractIntegrityGuard.psm1',
    'LOS.ContractSystem.psm1',
    'LOS.AuditLayer.psm1',
    'LOS.ContractRuntimeBroker.psm1',
    'LOS.ExecutionAttestationLayer.psm1',
    'LOS.ContractExecutionLedger.psm1',
    'LOS.DriftEvaluator.psm1',
    'LOS.ExecutionLifecycleEnforcer.psm1',
    'LOS.DCEK.CertificationHarness.psm1'
)

Invoke-SmokeCheck -Name 'Required LOS modules import successfully' -ScriptBlock {
    foreach ($moduleName in $requiredModules) {
        $modulePath = Join-Path $toolsRoot $moduleName
        if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
            throw "Required module is missing: $modulePath"
        }
        Import-SmokeModule -Path $modulePath
    }

    'Imported {0} modules.' -f $requiredModules.Count
}

$inputPayload = @{ Message = 'DCEK certification smoke test' }
$certContext = @{
    Runtime     = 'PS5'
    RequestedBy = 'CertificationHarness'
    Mode        = 'Full'
}

Invoke-SmokeCheck -Name 'Invoke-LifecycleExecution returns CERTIFIED' -ScriptBlock {
    Reset-SmokeModules
    Import-SmokeModule -Path (Join-Path $toolsRoot 'LOS.ExecutionLifecycleEnforcer.psm1')

    $result = Invoke-LifecycleExecution `
        -ContractId 'EKOS.Execute' `
        -ContractVersion '1.0.0' `
        -InputPayload $inputPayload `
        -ExecutionContext $certContext

    Assert-Smoke `
        -Condition ([string]::Equals(
            [string]$result.finalVerdict,
            'CERTIFIED',
            [StringComparison]::Ordinal
        )) `
        -Message ("Expected finalVerdict CERTIFIED, got '$($result.finalVerdict)'. Detail: {0}" -f `
            (Get-SmokeLifecycleFailureDetail -LifecycleResult $result))
    Assert-Smoke `
        -Condition ([string]::Equals(
            [string]$result.postflight,
            'PASS',
            [StringComparison]::Ordinal
        )) `
        -Message "Expected postflight PASS, got '$($result.postflight)'."

    'preflight={0}; execution={1}; postflight={2}; finalVerdict={3}' -f `
        $result.preflight,
        $result.execution,
        $result.postflight,
        $result.finalVerdict
}

Invoke-SmokeCheck -Name 'Run-PS5Execution returns Completed/CERTIFIED' -ScriptBlock {
    Reset-SmokeModules
    Import-SmokeModule -Path (Join-Path $toolsRoot 'LOS.DCEK.CertificationHarness.psm1')

    $result = Run-PS5Execution `
        -ContractId 'EKOS.Execute' `
        -ContractVersion '1.0.0' `
        -InputPayload $inputPayload `
        -ExecutionContext $certContext

    Assert-Smoke `
        -Condition ([string]::Equals(
            [string]$result.Output.Status,
            'Completed',
            [StringComparison]::Ordinal
        )) `
        -Message ("Expected Run-PS5Execution output Completed, got '$($result.Output.Status)'. Detail: {0}" -f `
            (Get-SmokeExecutionFailureDetail -ExecutionResult $result))
    Assert-Smoke `
        -Condition ([string]::Equals(
            [string]$result.Output.Result.finalVerdict,
            'CERTIFIED',
            [StringComparison]::Ordinal
        )) `
        -Message "Expected Run-PS5Execution finalVerdict CERTIFIED, got '$($result.Output.Result.finalVerdict)'."
    Assert-Smoke `
        -Condition ([bool]$result.ExecutionTrace.ContractResolved -and
            [bool]$result.ExecutionTrace.SchemaLoaded -and
            [bool]$result.ExecutionTrace.PreflightExecuted -and
            [bool]$result.ExecutionTrace.PostflightValidated) `
        -Message 'Run-PS5Execution audit trace is incomplete.'

    'Status={0}; finalVerdict={1}; schemaHash={2}' -f `
        $result.Output.Status,
        $result.Output.Result.finalVerdict,
        $result.SchemaHash
}

try {
    Reset-SmokeModules
    Import-SmokeModule -Path (Join-Path $toolsRoot 'LOS.DCEK.CertificationHarness.psm1')

    $ps7Result = Run-PS7Execution `
        -ContractId 'EKOS.Execute' `
        -ContractVersion '1.0.0' `
        -InputPayload $inputPayload `
        -ExecutionContext $certContext

    if (-not [string]::Equals(
        [string]$ps7Result.Output.Status,
        'Completed',
        [StringComparison]::Ordinal
    )) {
        throw ("Expected Run-PS7Execution output Completed, got '$($ps7Result.Output.Status)'. Detail: {0}" -f `
            (Get-SmokeExecutionFailureDetail -ExecutionResult $ps7Result))
    }

    if (-not [string]::Equals(
        [string]$ps7Result.Output.Result.finalVerdict,
        'CERTIFIED',
        [StringComparison]::Ordinal
    )) {
        throw "Expected Run-PS7Execution finalVerdict CERTIFIED, got '$($ps7Result.Output.Result.finalVerdict)'."
    }

    if (-not (
        [bool]$ps7Result.ExecutionTrace.ContractResolved -and
        [bool]$ps7Result.ExecutionTrace.SchemaLoaded -and
        [bool]$ps7Result.ExecutionTrace.PreflightExecuted -and
        [bool]$ps7Result.ExecutionTrace.PostflightValidated
    )) {
        throw 'Run-PS7Execution audit trace is incomplete.'
    }

    Add-SmokeResult `
        -Status PASS `
        -Name 'Run-PS7Execution returns Completed/CERTIFIED' `
        -Detail ('Status={0}; finalVerdict={1}; schemaHash={2}' -f `
            $ps7Result.Output.Status,
            $ps7Result.Output.Result.finalVerdict,
            $ps7Result.SchemaHash)
}
catch {
    $message = $_.Exception.Message
    if (Test-SmokePs7EnvironmentSkip -Message $message) {
        Add-SmokeResult `
            -Status SKIP `
            -Name 'Run-PS7Execution returns Completed/CERTIFIED' `
            -Detail ('PS7 runtime could not launch in this environment: {0}' -f $message)
    }
    else {
        Add-SmokeResult `
            -Status FAIL `
            -Name 'Run-PS7Execution returns Completed/CERTIFIED' `
            -Detail $message
    }
}

Invoke-SmokeCheck -Name 'Direct broker invocation remains blocked' -ScriptBlock {
    Reset-SmokeModules
    Import-SmokeModule -Path (Join-Path $toolsRoot 'LOS.ContractRuntimeBroker.psm1')

    $operation = {
        param([hashtable]$Context)
        return [pscustomobject][ordered]@{ Accepted = $true }
    }

    $result = Invoke-ContractedExecution `
        -ContractId 'EKOS.Execute' `
        -Version '1.0.0' `
        -Operation $operation `
        -Request @{} `
        -Context @{}

    Assert-Smoke `
        -Condition ([string]::Equals(
            [string]$result.Status,
            'Blocked',
            [StringComparison]::Ordinal
        )) `
        -Message "Expected direct broker status Blocked, got '$($result.Status)'."
    Assert-Smoke `
        -Condition (-not [bool]$result.Audit.ContractResolved) `
        -Message 'Direct broker call unexpectedly resolved a contract.'

    'Blocked with fail-closed broker authorization.'
}

Invoke-SmokeCheck -Name 'Normal child script does not call broker directly' -ScriptBlock {
    $harnessPath = Join-Path $toolsRoot 'LOS.DCEK.CertificationHarness.psm1'
    $text = [IO.File]::ReadAllText($harnessPath)
    $start = $text.IndexOf(
        'function New-LosExecutionChildScript',
        [StringComparison]::Ordinal
    )
    $end = $text.IndexOf(
        'function ConvertTo-LosExecutionCapture',
        [StringComparison]::Ordinal
    )
    Assert-Smoke `
        -Condition ($start -ge 0 -and $end -gt $start) `
        -Message 'Could not locate New-LosExecutionChildScript block.'

    $block = $text.Substring($start, $end - $start)
    Assert-Smoke `
        -Condition ($block.IndexOf(
            'Invoke-ContractedExecution',
            [StringComparison]::Ordinal
        ) -lt 0) `
        -Message 'Normal child execution script still references Invoke-ContractedExecution.'
    Assert-Smoke `
        -Condition ($block.IndexOf(
            'Invoke-LifecycleExecution',
            [StringComparison]::Ordinal
        ) -ge 0) `
        -Message 'Normal child execution script does not reference Invoke-LifecycleExecution.'

    'Normal child path is lifecycle-enforcer mediated.'
}

Invoke-SmokeCheck -Name 'LOS tools do not use PowerShellEdition or PowerShellVersion' -ScriptBlock {
    $matches = New-Object 'System.Collections.Generic.List[string]'
    $files = Get-ChildItem -LiteralPath $toolsRoot -Filter 'LOS*' -File
    foreach ($file in $files) {
        $text = [IO.File]::ReadAllText($file.FullName)
        if ($text.IndexOf('PowerShellEdition', [StringComparison]::Ordinal) -ge 0 -or
            $text.IndexOf('PowerShellVersion', [StringComparison]::Ordinal) -ge 0) {
            $matches.Add($file.FullName)
        }
    }

    Assert-Smoke `
        -Condition ($matches.Count -eq 0) `
        -Message ('Forbidden runtime aliases found in: {0}' -f ($matches.ToArray() -join ', '))

    'No forbidden runtime aliases found.'
}

Invoke-SmokeCheck -Name 'LOS tools do not use unsafe .Contains(' -ScriptBlock {
    $matches = New-Object 'System.Collections.Generic.List[string]'
    $files = Get-ChildItem -LiteralPath $toolsRoot -Filter 'LOS*' -File
    foreach ($file in $files) {
        $text = [IO.File]::ReadAllText($file.FullName)
        if ([regex]::IsMatch($text, '\.Contains\s*\(')) {
            $matches.Add($file.FullName)
        }
    }

    Assert-Smoke `
        -Condition ($matches.Count -eq 0) `
        -Message ('Unsafe .Contains( usage found in: {0}' -f ($matches.ToArray() -join ', '))

    'No unsafe .Contains( usage found.'
}

Write-Host ''
Write-Host 'LOS DCEK Smoke Test'
Write-Host '==================='
foreach ($result in $script:Results) {
    $line = '[{0}] {1}' -f $result.Status, $result.Name
    if (-not [string]::IsNullOrEmpty([string]$result.Detail)) {
        $line = '{0} - {1}' -f $line, $result.Detail
    }
    Write-Host $line
}

$failed = @($script:Results | Where-Object {
    [string]::Equals([string]$_.Status, 'FAIL', [StringComparison]::Ordinal)
})
$passed = @($script:Results | Where-Object {
    [string]::Equals([string]$_.Status, 'PASS', [StringComparison]::Ordinal)
})
$skipped = @($script:Results | Where-Object {
    [string]::Equals([string]$_.Status, 'SKIP', [StringComparison]::Ordinal)
})

Write-Host ''
Write-Host ('Summary: PASS={0} FAIL={1} SKIP={2}' -f `
    $passed.Count,
    $failed.Count,
    $skipped.Count)

if ($failed.Count -gt 0) {
    exit 1
}

exit 0
