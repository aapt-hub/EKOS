Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$runtimePath = Join-Path $PSScriptRoot 'EKOS.GraphRuntime.psm1'
$serializerPath = Join-Path $PSScriptRoot 'EKOS.CanonicalSerializer.psm1'
$guardPath = Join-Path $PSScriptRoot 'LOS.ContractIntegrityGuard.psm1'

function Import-LosKernelDependency {
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
            throw "Unauthorized LOS kernel dependency path for '$ModuleName'."
        }
        return
    }

    Import-Module $resolvedPath -ErrorAction Stop
}

Import-LosKernelDependency `
    -ModuleName 'EKOS.GraphRuntime' `
    -ModulePath $runtimePath
Import-LosKernelDependency `
    -ModuleName 'EKOS.CanonicalSerializer' `
    -ModulePath $serializerPath
Import-LosKernelDependency `
    -ModuleName 'LOS.ContractIntegrityGuard' `
    -ModulePath $guardPath

function Get-LosObjectProperty {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Value,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($null -eq $Value) {
        return [PSCustomObject]@{
            Exists = $false
            Value  = $null
        }
    }

    if ($Value -is [System.Collections.IDictionary]) {
        foreach ($key in $Value.Keys) {
            if ([System.StringComparer]::Ordinal.Equals(
                [string]$key,
                $Name
            )) {
                return [PSCustomObject]@{
                    Exists = $true
                    Value  = $Value[$key]
                }
            }
        }

        return [PSCustomObject]@{
            Exists = $false
            Value  = $null
        }
    }

    foreach ($property in $Value.PSObject.Properties) {
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

function Test-LosObjectValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value -or
        $Value -is [string] -or
        $Value -is [ValueType] -or
        $Value -is [System.Collections.IEnumerable] -and
        $Value -isnot [System.Collections.IDictionary]) {
        return $false
    }

    return $true
}

function Get-LosObjectDepth {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value -or
        $Value -is [string] -or
        $Value -is [ValueType]) {
        return [int64]0
    }

    $maximumChildDepth = [int64]0

    if ($Value -is [System.Collections.IDictionary]) {
        foreach ($entry in $Value.GetEnumerator()) {
            $childDepth = Get-LosObjectDepth -Value $entry.Value
            if ($childDepth -gt $maximumChildDepth) {
                $maximumChildDepth = $childDepth
            }
        }
        return [int64](1 + $maximumChildDepth)
    }

    if ($Value -is [System.Collections.IEnumerable]) {
        foreach ($item in $Value) {
            $childDepth = Get-LosObjectDepth -Value $item
            if ($childDepth -gt $maximumChildDepth) {
                $maximumChildDepth = $childDepth
            }
        }
        return [int64](1 + $maximumChildDepth)
    }

    foreach ($property in $Value.PSObject.Properties) {
        if ($property.MemberType -in @(
            'Property',
            'NoteProperty',
            'AliasProperty'
        )) {
            $childDepth = Get-LosObjectDepth -Value $property.Value
            if ($childDepth -gt $maximumChildDepth) {
                $maximumChildDepth = $childDepth
            }
        }
    }

    return [int64](1 + $maximumChildDepth)
}

function Test-LosSchemaValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Value,

        [Parameter(Mandatory)]
        [object]$Schema,

        [Parameter(Mandatory)]
        [string]$Scope
    )

    if ($null -eq $Value) {
        if ([bool]$Schema.required) {
            throw "LOS $Scope value is required."
        }
        return
    }

    if ($Schema.type -ceq 'object') {
        if (-not (Test-LosObjectValue -Value $Value)) {
            throw "LOS $Scope value must be an object."
        }

        foreach ($property in $Schema.properties.PSObject.Properties) {
            $propertySchema = $property.Value
            $resolvedProperty = Get-LosObjectProperty `
                -Value $Value `
                -Name $property.Name

            if ([bool]$propertySchema.required -and
                -not [bool]$resolvedProperty.Exists) {
                throw "LOS $Scope property '$($property.Name)' is required."
            }

            if ([bool]$resolvedProperty.Exists -and
                $propertySchema.type -ceq 'object' -and
                -not (Test-LosObjectValue -Value $resolvedProperty.Value)) {
                throw "LOS $Scope property '$($property.Name)' must be an object."
            }
        }
        return
    }

    throw "Unsupported LOS schema type in ${Scope}: $($Schema.type)"
}

function Compare-LosRuleValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Actual,

        [Parameter(Mandatory)]
        [string]$Operator,

        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Expected
    )

    if ($Actual -is [ValueType] -and
        $Actual -isnot [bool] -and
        $Expected -is [ValueType] -and
        $Expected -isnot [bool]) {
        $left = [decimal]$Actual
        $right = [decimal]$Expected
        switch ($Operator) {
            '<=' { return ($left -le $right) }
            '>=' { return ($left -ge $right) }
            '<'  { return ($left -lt $right) }
            '>'  { return ($left -gt $right) }
            '==' { return ($left -eq $right) }
            '!=' { return ($left -ne $right) }
        }
    }

    $comparison = [System.StringComparer]::Ordinal.Compare(
        [string]$Actual,
        [string]$Expected
    )
    switch ($Operator) {
        '<=' { return ($comparison -le 0) }
        '>=' { return ($comparison -ge 0) }
        '<'  { return ($comparison -lt 0) }
        '>'  { return ($comparison -gt 0) }
        '==' { return ($comparison -eq 0) }
        '!=' { return ($comparison -ne 0) }
    }

    throw "Unsupported LOS rule operator: $Operator"
}

function Test-LosRuleSet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Rules,

        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Value,

        [Parameter(Mandatory)]
        [object]$Contract,

        [Parameter(Mandatory)]
        [string]$Scope
    )

    foreach ($rule in $Rules) {
        $actual = if ($rule.field -ceq 'maxDepth') {
            Get-LosObjectDepth -Value $Value
        }
        else {
            $constraintProperty = Get-LosObjectProperty `
                -Value $Contract.executionConstraints `
                -Name ([string]$rule.field)
            if (-not [bool]$constraintProperty.Exists) {
                throw "LOS $Scope rule field is unavailable: $($rule.field)"
            }
            $constraintProperty.Value
        }

        if (-not (Compare-LosRuleValue `
            -Actual $actual `
            -Operator ([string]$rule.operator) `
            -Expected $rule.value)) {
            throw "LOS $Scope rule failed: $($rule.source)"
        }
    }
}

function Test-LosRuntimeError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return $false
    }

    foreach ($propertyName in @(
        'Type',
        'Message',
        'Category',
        'Stack',
        'Target',
        'Runtime'
    )) {
        if ($null -eq $Value.PSObject.Properties[$propertyName]) {
            return $false
        }
    }

    return $true
}

function ConvertTo-LosKernelError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $canonical = ConvertTo-EkosCanonicalError -ErrorRecord $ErrorRecord
    return [PSCustomObject][ordered]@{
        Type     = [string]$canonical.Type
        Message  = [string]$canonical.Message
        Category = [string]$canonical.Category
        Target   = [string]$canonical.Target
    }
}

function ConvertFrom-LosRuntimeError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$RuntimeError
    )

    return [PSCustomObject][ordered]@{
        Type     = [string]$RuntimeError.Type
        Message  = [string]$RuntimeError.Message
        Category = [string]$RuntimeError.Category
        Target   = [string]$RuntimeError.Target
    }
}

function Invoke-ContractedExecution {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$IntegrityAttestation,

        [Parameter(Mandatory)]
        [scriptblock]$Operation,

        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Request,

        [Parameter(Mandatory)]
        [AllowNull()]
        [hashtable]$Context
    )

    $preFlightExecuted = $false
    $preFlightPassed = $false
    $postFlightValidated = $false
    $integrityVerified = $false
    $output = $null

    try {
        $preFlightIntegrity = Invoke-IntegrityCheck `
            -Phase 'PreFlight' `
            -Attestation $IntegrityAttestation

        $integrityVerified = $true
        $preFlightExecuted = $true
        $contract = $IntegrityAttestation.Schema
        $inputEnvelope = [PSCustomObject][ordered]@{
            Context = $Context
            Request = $Request
        }

        Test-LosSchemaValue `
            -Value $inputEnvelope `
            -Schema $contract.inputs `
            -Scope 'input'
        Test-LosRuleSet `
            -Rules @($contract.rules.inputs) `
            -Value $inputEnvelope `
            -Contract $contract `
            -Scope 'input'
        Test-LosRuleSet `
            -Rules @($contract.rules.execution) `
            -Value $contract.executionConstraints `
            -Contract $contract `
            -Scope 'execution'
        $preFlightPassed = $true

        $executionContext = @{
            Context  = $Context
            Contract = $contract
            Request  = $Request
        }
        $output = Invoke-EkosRuntime `
            -Script $Operation `
            -Context $executionContext

        if (Test-LosRuntimeError -Value $output) {
            return [PSCustomObject][ordered]@{
                Status              = 'Failed'
                Output              = $null
                Error               = ConvertFrom-LosRuntimeError `
                    -RuntimeError $output
                IntegrityVerified   = $integrityVerified
                PreflightExecuted   = $preFlightExecuted
                PostflightValidated = $false
                SchemaHash          = $preFlightIntegrity.SchemaHash
            }
        }

        $integrityVerified = $false
        $postFlightIntegrity = Invoke-IntegrityCheck `
            -Phase 'PostFlight' `
            -Attestation $IntegrityAttestation
        $integrityVerified = $true

        Test-LosSchemaValue `
            -Value $output `
            -Schema $contract.outputs `
            -Scope 'output'
        Test-LosRuleSet `
            -Rules @($contract.rules.outputs) `
            -Value $output `
            -Contract $contract `
            -Scope 'output'

        $outputBytes = [System.Text.Encoding]::UTF8.GetByteCount(
            (ConvertTo-EkosCanonicalJson -InputObject $output)
        )
        if ($outputBytes -gt [int64]$contract.executionConstraints.memoryBytes) {
            throw 'LOS output exceeds the contract memoryBytes limit.'
        }

        $postFlightValidated = $true
        return [PSCustomObject][ordered]@{
            Status              = 'Completed'
            Output              = $output
            Error               = $null
            IntegrityVerified   = $true
            PreflightExecuted   = $preFlightExecuted
            PostflightValidated = $postFlightValidated
            SchemaHash          = $postFlightIntegrity.SchemaHash
        }
    }
    catch {
        return [PSCustomObject][ordered]@{
            Status              = if ($preFlightPassed) {
                'Failed'
            }
            else {
                'Blocked'
            }
            Output              = $null
            Error               = ConvertTo-LosKernelError -ErrorRecord $_
            IntegrityVerified   = $integrityVerified
            PreflightExecuted   = $preFlightExecuted
            PostflightValidated = $postFlightValidated
            SchemaHash          = if (
                $null -ne $IntegrityAttestation.PSObject.Properties['SchemaHash']
            ) {
                [string]$IntegrityAttestation.SchemaHash
            }
            else {
                ''
            }
        }
    }
}

Export-ModuleMember -Function Invoke-ContractedExecution
