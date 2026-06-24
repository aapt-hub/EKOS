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

$script:LosContractRegistry = [ordered]@{
    Contracts = [ordered]@{
        'EKOS.Execute' = [ordered]@{
            '1.0.0' = [ordered]@{
                contractId          = 'EKOS.Execute'
                version             = '1.0.0'
                executionModel      = 'BROKER_GUARDED'
                inputs              = [ordered]@{
                    type        = 'object'
                    required    = $true
                    properties  = [ordered]@{
                        Context = [ordered]@{
                            type     = 'object'
                            required = $true
                        }
                        Request = [ordered]@{
                            type     = 'object'
                            required = $true
                        }
                    }
                    constraints = @(
                        'maxDepth <= 12'
                    )
                }
                outputs             = [ordered]@{
                    type        = 'object'
                    required    = $false
                    properties  = [ordered]@{}
                    constraints = @(
                        'maxDepth <= 12'
                    )
                }
                executionConstraints = [ordered]@{
                    timeoutMs   = 30000
                    memoryBytes = 268435456
                    determinism = 'REQUIRED'
                    constraints = @(
                        'timeoutMs <= 30000',
                        'memoryBytes <= 268435456',
                        'determinism == REQUIRED'
                    )
                }
                compatibility       = [ordered]@{
                    PS5 = $true
                    PS7 = $true
                }
                failureMode         = 'FAIL_CLOSED'
                auditLevel          = 'FULL_TRACE'
                auditMetadata       = [ordered]@{
                    required = @(
                        'ContractResolved',
                        'SchemaLoaded',
                        'VersionValidated'
                    )
                }
                ruleSetId           = 'EKOS.Execute/1.0.0'
                policyId            = 'EKOS.Execute/1.0.0'
                versionId           = 'EKOS.Execute/1.0.0'
            }
        }
    }
    Rules     = [ordered]@{
        'EKOS.Execute/1.0.0' = [ordered]@{
            inputs = @(
                'maxDepth <= 12'
            )
            outputs = @(
                'maxDepth <= 12'
            )
            execution = @(
                'timeoutMs <= 30000',
                'memoryBytes <= 268435456',
                'determinism == REQUIRED'
            )
        }
    }
    Policies  = [ordered]@{
        'EKOS.Execute/1.0.0' = [ordered]@{
            failureMode   = 'FAIL_CLOSED'
            auditLevel    = 'FULL_TRACE'
            auditMetadata = @(
                'ContractResolved',
                'SchemaLoaded',
                'VersionValidated'
            )
        }
    }
    Versions  = [ordered]@{
        'EKOS.Execute' = [ordered]@{
            available     = @(
                '1.0.0'
            )
            compatibility = [ordered]@{
                '1.0.0' = [ordered]@{
                    PS5 = $true
                    PS7 = $true
                }
            }
        }
    }
}

function Test-LosDictionaryKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Dictionary,

        [Parameter(Mandatory)]
        [string]$Name
    )

    foreach ($key in $Dictionary.Keys) {
        if ([System.StringComparer]::Ordinal.Equals(
            [string]$key,
            $Name
        )) {
            return $true
        }
    }

    return $false
}

function Copy-LosSchemaValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return [PSCustomObject]@{ Value = $null }
    }

    if ($Value -is [string]) {
        return [PSCustomObject]@{
            Value = $Value.Normalize(
                [System.Text.NormalizationForm]::FormC
            )
        }
    }

    if ($Value -is [bool] -or
        $Value -is [byte] -or
        $Value -is [sbyte] -or
        $Value -is [int16] -or
        $Value -is [uint16] -or
        $Value -is [int32] -or
        $Value -is [uint32] -or
        $Value -is [int64] -or
        $Value -is [uint64] -or
        $Value -is [decimal] -or
        $Value -is [double] -or
        $Value -is [single]) {
        return [PSCustomObject]@{ Value = $Value }
    }

    if ($Value -is [System.Collections.IDictionary]) {
        $keys = [System.Collections.Generic.List[string]]::new()
        foreach ($key in $Value.Keys) {
            $keys.Add(([string]$key).Normalize(
                [System.Text.NormalizationForm]::FormC
            ))
        }
        $keys.Sort([System.StringComparer]::Ordinal)

        $copy = [ordered]@{}
        foreach ($key in $keys) {
            if (Test-LosDictionaryKey -Dictionary $copy -Name $key) {
                throw "Corrupt LOS registry: duplicate key '$key'."
            }

            $child = Copy-LosSchemaValue -Value $Value[$key]
            $copy[$key] = $child.Value
        }

        return [PSCustomObject]@{ Value = [PSCustomObject]$copy }
    }

    if ($Value -is [System.Collections.IEnumerable]) {
        $items = [System.Collections.Generic.List[object]]::new()
        foreach ($item in $Value) {
            $child = Copy-LosSchemaValue -Value $item
            $items.Add($child.Value)
        }

        return [PSCustomObject]@{ Value = $items.ToArray() }
    }

    $properties = [System.Collections.Generic.List[string]]::new()
    foreach ($property in $Value.PSObject.Properties) {
        if ($property.MemberType -in @(
            'Property',
            'NoteProperty',
            'AliasProperty'
        )) {
            $properties.Add($property.Name.Normalize(
                [System.Text.NormalizationForm]::FormC
            ))
        }
    }
    $properties.Sort([System.StringComparer]::Ordinal)

    $objectCopy = [ordered]@{}
    foreach ($propertyName in $properties) {
        if (Test-LosDictionaryKey `
            -Dictionary $objectCopy `
            -Name $propertyName) {
            throw "Corrupt LOS registry: duplicate property '$propertyName'."
        }

        $child = Copy-LosSchemaValue `
            -Value $Value.PSObject.Properties[$propertyName].Value
        $objectCopy[$propertyName] = $child.Value
    }

    return [PSCustomObject]@{
        Value = [PSCustomObject]$objectCopy
    }
}

function ConvertTo-LosSchemaObject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object]$Value
    )

    $copy = Copy-LosSchemaValue -Value $Value
    return $copy.Value
}

function Test-LosSemanticVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Version
    )

    return [bool](
        $Version -match '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$'
    )
}

function Get-LosExactRegistryKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Dictionary,

        [Parameter(Mandatory)]
        [string]$RequestedKey,

        [Parameter(Mandatory)]
        [string]$RegistryName
    )

    foreach ($key in $Dictionary.Keys) {
        if ([System.StringComparer]::Ordinal.Equals(
            [string]$key,
            $RequestedKey
        )) {
            return [string]$key
        }
    }

    throw "$RegistryName does not contain exact key: $RequestedKey"
}

function Resolve-Version {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ContractId,

        [Parameter(Mandatory)]
        [string]$Version
    )

    if (-not (Test-LosSemanticVersion -Version $Version)) {
        throw "Invalid semantic version '$Version'. Expected MAJOR.MINOR.PATCH."
    }

    $contractKey = Get-LosExactRegistryKey `
        -Dictionary $script:LosContractRegistry.Versions `
        -RequestedKey $ContractId `
        -RegistryName 'LOS Versions registry'
    $versionRegistry = $script:LosContractRegistry.Versions[$contractKey]
    $matchedVersion = $null
    foreach ($availableVersion in $versionRegistry.available) {
        if ([System.StringComparer]::Ordinal.Equals(
            [string]$availableVersion,
            $Version
        )) {
            $matchedVersion = [string]$availableVersion
            break
        }
    }

    if ($null -eq $matchedVersion) {
        throw "Unknown LOS contract version: $ContractId@$Version"
    }

    return $matchedVersion
}

function Load-SchemaFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ContractId,

        [Parameter(Mandatory)]
        [string]$Version
    )

    $contractKey = Get-LosExactRegistryKey `
        -Dictionary $script:LosContractRegistry.Contracts `
        -RequestedKey $ContractId `
        -RegistryName 'LOS Contracts registry'
    $contracts = $script:LosContractRegistry.Contracts[$contractKey]
    $versionKey = Get-LosExactRegistryKey `
        -Dictionary $contracts `
        -RequestedKey $Version `
        -RegistryName "LOS contract '$ContractId'"

    return ConvertTo-LosSchemaObject -Value $contracts[$versionKey]
}

function ConvertTo-LosRuleValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Value
    )

    if ([System.StringComparer]::OrdinalIgnoreCase.Equals($Value, 'true')) {
        return [PSCustomObject]@{
            Type  = 'boolean'
            Value = $true
        }
    }

    if ([System.StringComparer]::OrdinalIgnoreCase.Equals($Value, 'false')) {
        return [PSCustomObject]@{
            Type  = 'boolean'
            Value = $false
        }
    }

    if ([System.StringComparer]::OrdinalIgnoreCase.Equals($Value, 'null')) {
        return [PSCustomObject]@{
            Type  = 'null'
            Value = $null
        }
    }

    $integer = [int64]0
    if ([int64]::TryParse(
        $Value,
        [System.Globalization.NumberStyles]::Integer,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [ref]$integer
    )) {
        return [PSCustomObject]@{
            Type  = 'integer'
            Value = $integer
        }
    }

    $decimal = [decimal]0
    if ([decimal]::TryParse(
        $Value,
        [System.Globalization.NumberStyles]::Float,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [ref]$decimal
    )) {
        return [PSCustomObject]@{
            Type  = 'number'
            Value = $decimal
        }
    }

    return [PSCustomObject]@{
        Type  = 'string'
        Value = $Value.Normalize(
            [System.Text.NormalizationForm]::FormC
        )
    }
}

function Normalize-RuleSet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Rules,

        [Parameter(Mandatory)]
        [string]$Scope
    )

    $normalizedRules = [System.Collections.Generic.List[object]]::new()
    $index = 0

    foreach ($rule in $Rules) {
        $index++
        if ($rule -isnot [string]) {
            throw "Invalid LOS rule in '$Scope': rules must be strings."
        }

        $ruleText = ([string]$rule).Normalize(
            [System.Text.NormalizationForm]::FormC
        )
        $match = [System.Text.RegularExpressions.Regex]::Match(
            $ruleText,
            '^\s*(?<field>[A-Za-z_][A-Za-z0-9_.]*)\s*(?<operator><=|>=|==|!=|<|>)\s*(?<value>.+?)\s*$',
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )
        if (-not $match.Success) {
            throw "Invalid LOS rule syntax in '$Scope': $ruleText"
        }

        $ruleValue = ConvertTo-LosRuleValue `
            -Value $match.Groups['value'].Value

        $normalizedRules.Add([PSCustomObject][ordered]@{
            ruleId    = (
                $Scope +
                '/' +
                $index.ToString(
                    'D4',
                    [System.Globalization.CultureInfo]::InvariantCulture
                )
            )
            field     = $match.Groups['field'].Value
            operator  = $match.Groups['operator'].Value
            valueType = $ruleValue.Type
            value     = $ruleValue.Value
            source    = $ruleText
        })
    }

    return ,$normalizedRules.ToArray()
}

function Bind-FailurePolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Schema
    )

    $policyIdProperty = $Schema.PSObject.Properties['policyId']
    if ($null -eq $policyIdProperty -or
        [string]::IsNullOrWhiteSpace([string]$policyIdProperty.Value)) {
        throw 'LOS schema must reference a policyId.'
    }

    $policyKey = Get-LosExactRegistryKey `
        -Dictionary $script:LosContractRegistry.Policies `
        -RequestedKey ([string]$policyIdProperty.Value) `
        -RegistryName 'LOS Policies registry'
    $policy = $script:LosContractRegistry.Policies[$policyKey]

    if ($policy.failureMode -cne 'FAIL_CLOSED' -or
        $Schema.failureMode -cne $policy.failureMode) {
        throw 'LOS schemas must use failureMode FAIL_CLOSED.'
    }

    if ($policy.auditLevel -cne 'FULL_TRACE' -or
        $Schema.auditLevel -cne $policy.auditLevel) {
        throw 'LOS schemas must use auditLevel FULL_TRACE.'
    }

    $requiredAuditMetadata = @($policy.auditMetadata)
    $actualAuditMetadata = @($Schema.auditMetadata.required)
    foreach ($requiredField in $requiredAuditMetadata) {
        $found = $false
        foreach ($actualField in $actualAuditMetadata) {
            if ([System.StringComparer]::Ordinal.Equals(
                [string]$actualField,
                $requiredField
            )) {
                $found = $true
                break
            }
        }

        if (-not $found) {
            throw "LOS schema is missing audit metadata: $requiredField"
        }
    }

    return [PSCustomObject][ordered]@{
        failureMode   = $policy.failureMode
        auditLevel    = $policy.auditLevel
        auditMetadata = [PSCustomObject][ordered]@{
            required = $requiredAuditMetadata
        }
    }
}

function Validate-SchemaStructure {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Schema
    )

    $requiredProperties = @(
        'contractId',
        'version',
        'executionModel',
        'inputs',
        'outputs',
        'executionConstraints',
        'compatibility',
        'failureMode',
        'auditLevel',
        'auditMetadata',
        'ruleSetId',
        'policyId',
        'versionId'
    )

    foreach ($propertyName in $requiredProperties) {
        if ($null -eq $Schema.PSObject.Properties[$propertyName]) {
            throw "Corrupt LOS schema: missing property '$propertyName'."
        }
    }

    if ([string]::IsNullOrWhiteSpace([string]$Schema.contractId)) {
        throw 'Corrupt LOS schema: contractId is required.'
    }

    if (-not (Test-LosSemanticVersion -Version ([string]$Schema.version))) {
        throw 'Corrupt LOS schema: version must be semantic MAJOR.MINOR.PATCH.'
    }

    $expectedVersionId = (
        [string]$Schema.contractId +
        '/' +
        [string]$Schema.version
    )
    if (-not [System.StringComparer]::Ordinal.Equals(
        [string]$Schema.versionId,
        $expectedVersionId
    )) {
        throw 'Corrupt LOS schema: versionId does not match contractId/version.'
    }

    if ([string]::IsNullOrWhiteSpace([string]$Schema.executionModel)) {
        throw 'Corrupt LOS schema: executionModel is required.'
    }

    foreach ($schemaName in @('inputs', 'outputs')) {
        $value = $Schema.$schemaName
        foreach ($propertyName in @(
            'type',
            'required',
            'properties',
            'constraints'
        )) {
            if ($null -eq $value.PSObject.Properties[$propertyName]) {
                throw "Corrupt LOS schema: $schemaName.$propertyName is required."
            }
        }

        if ($value.type -cne 'object') {
            throw "Corrupt LOS schema: $schemaName.type must be object."
        }
    }

    foreach ($propertyName in @(
        'timeoutMs',
        'memoryBytes',
        'determinism',
        'constraints'
    )) {
        if ($null -eq $Schema.executionConstraints.PSObject.Properties[$propertyName]) {
            throw "Corrupt LOS schema: executionConstraints.$propertyName is required."
        }
    }

    if ([int64]$Schema.executionConstraints.timeoutMs -le 0) {
        throw 'Corrupt LOS schema: timeoutMs must be greater than zero.'
    }

    if ([int64]$Schema.executionConstraints.memoryBytes -le 0) {
        throw 'Corrupt LOS schema: memoryBytes must be greater than zero.'
    }

    if ($Schema.executionConstraints.determinism -cne 'REQUIRED') {
        throw 'Corrupt LOS schema: determinism must be REQUIRED.'
    }

    foreach ($runtime in @('PS5', 'PS7')) {
        if ($null -eq $Schema.compatibility.PSObject.Properties[$runtime]) {
            throw "Corrupt LOS schema: compatibility.$runtime is required."
        }

        if ($Schema.compatibility.$runtime -isnot [bool]) {
            throw "Corrupt LOS schema: compatibility.$runtime must be Boolean."
        }
    }

    [void](Bind-FailurePolicy -Schema $Schema)
    return $true
}

function Get-LosRuntimeKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$RuntimeContext
    )

    if ($RuntimeContext -is [string]) {
        if ($RuntimeContext -ceq 'PS5' -or $RuntimeContext -ceq 'PS7') {
            return [string]$RuntimeContext
        }

        throw "Unknown LOS runtime context: $RuntimeContext"
    }

    $runtimeProperty = $RuntimeContext.PSObject.Properties['Runtime']
    if ($null -ne $runtimeProperty) {
        $runtime = [string]$runtimeProperty.Value
        if ($runtime -ceq 'PS5' -or $runtime -ceq 'PS7') {
            return $runtime
        }

        throw "Unknown LOS runtime context: $runtime"
    }

    $editionProperty = $RuntimeContext.PSObject.Properties['Edition']
    if ($null -ne $editionProperty) {
        $edition = [string]$editionProperty.Value
        if ($edition -ceq 'Desktop') {
            return 'PS5'
        }
        if ($edition -ceq 'Core') {
            return 'PS7'
        }

        throw "Unknown PowerShell edition: $edition"
    }

    $versionProperty = $RuntimeContext.PSObject.Properties['PSVersion']
    if ($null -ne $versionProperty) {
        $version = [version]([string]$versionProperty.Value)
        if ($version.Major -eq 5) {
            return 'PS5'
        }
        if ($version.Major -ge 7) {
            return 'PS7'
        }

        throw "Unsupported PowerShell runtime version: $version"
    }

    throw 'Runtime context must specify Runtime, Edition, or PSVersion.'
}

function Test-LosOrdinalSequence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Left,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Right
    )

    if ($Left.Count -ne $Right.Count) {
        return $false
    }

    for ($index = 0; $index -lt $Left.Count; $index++) {
        if (-not [System.StringComparer]::Ordinal.Equals(
            [string]$Left[$index],
            [string]$Right[$index]
        )) {
            return $false
        }
    }

    return $true
}

function Evaluate-Compatibility {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$CompatibilityMatrix,

        [Parameter(Mandatory)]
        [object]$RuntimeContext
    )

    $runtimeKey = Get-LosRuntimeKey -RuntimeContext $RuntimeContext
    $runtimeProperty = $CompatibilityMatrix.PSObject.Properties[$runtimeKey]
    if ($null -eq $runtimeProperty) {
        throw "Compatibility matrix does not define runtime: $runtimeKey"
    }

    if ($runtimeProperty.Value -isnot [bool]) {
        throw "Compatibility value for $runtimeKey must be Boolean."
    }

    if (-not [bool]$runtimeProperty.Value) {
        throw "Contract is incompatible with runtime: $runtimeKey"
    }

    return [PSCustomObject][ordered]@{
        Runtime      = $runtimeKey
        IsCompatible = $true
    }
}

function Get-ContractDefinition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ContractId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Version
    )

    $resolvedVersion = Resolve-Version `
        -ContractId $ContractId `
        -Version $Version
    $schema = Load-SchemaFile `
        -ContractId $ContractId `
        -Version $resolvedVersion

    [void](Validate-SchemaStructure -Schema $schema)
    return ConvertTo-LosSchemaObject -Value $schema
}

function Get-CompatibilityMatrix {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ContractId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Version
    )

    $resolvedVersion = Resolve-Version `
        -ContractId $ContractId `
        -Version $Version
    $contractKey = Get-LosExactRegistryKey `
        -Dictionary $script:LosContractRegistry.Versions `
        -RequestedKey $ContractId `
        -RegistryName 'LOS Versions registry'
    $versionRegistry = $script:LosContractRegistry.Versions[$contractKey]

    $versionKey = Get-LosExactRegistryKey `
        -Dictionary $versionRegistry.compatibility `
        -RequestedKey $resolvedVersion `
        -RegistryName "LOS compatibility matrix '$ContractId'"

    $matrix = ConvertTo-LosSchemaObject `
        -Value $versionRegistry.compatibility[$versionKey]

    foreach ($runtime in @('PS5', 'PS7')) {
        if ($null -eq $matrix.PSObject.Properties[$runtime] -or
            $matrix.$runtime -isnot [bool]) {
            throw "Corrupt compatibility matrix for $ContractId@$resolvedVersion."
        }
    }

    return [PSCustomObject][ordered]@{
        contractId = $ContractId
        version    = $resolvedVersion
        matrix     = $matrix
    }
}

function Resolve-ContractSchema {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ContractId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Version,

        [Parameter(Mandatory)]
        [object]$RuntimeContext
    )

    $schema = Get-ContractDefinition `
        -ContractId $ContractId `
        -Version $Version
    $compatibility = Get-CompatibilityMatrix `
        -ContractId $ContractId `
        -Version $Version
    $compatibilityResult = Evaluate-Compatibility `
        -CompatibilityMatrix $compatibility.matrix `
        -RuntimeContext $RuntimeContext

    foreach ($runtime in @('PS5', 'PS7')) {
        if ([bool]$schema.compatibility.$runtime -ne
            [bool]$compatibility.matrix.$runtime) {
            throw "Schema compatibility does not match Versions registry for $runtime."
        }
    }

    $ruleSetId = [string]$schema.ruleSetId
    $ruleSetKey = Get-LosExactRegistryKey `
        -Dictionary $script:LosContractRegistry.Rules `
        -RequestedKey $ruleSetId `
        -RegistryName 'LOS Rules registry'
    $rules = $script:LosContractRegistry.Rules[$ruleSetKey]
    if (-not (Test-LosOrdinalSequence `
        -Left @($schema.inputs.constraints) `
        -Right @($rules.inputs))) {
        throw 'Schema input constraints do not match the Rules registry.'
    }
    if (-not (Test-LosOrdinalSequence `
        -Left @($schema.outputs.constraints) `
        -Right @($rules.outputs))) {
        throw 'Schema output constraints do not match the Rules registry.'
    }
    if (-not (Test-LosOrdinalSequence `
        -Left @($schema.executionConstraints.constraints) `
        -Right @($rules.execution))) {
        throw 'Schema execution constraints do not match the Rules registry.'
    }

    $normalizedRules = [PSCustomObject][ordered]@{
        inputs = Normalize-RuleSet `
            -Rules @($rules.inputs) `
            -Scope ($ruleSetId + '/inputs')
        outputs = Normalize-RuleSet `
            -Rules @($rules.outputs) `
            -Scope ($ruleSetId + '/outputs')
        execution = Normalize-RuleSet `
            -Rules @($rules.execution) `
            -Scope ($ruleSetId + '/execution')
    }

    $policy = Bind-FailurePolicy -Schema $schema

    return [PSCustomObject][ordered]@{
        contractId          = $schema.contractId
        version             = $schema.version
        executionModel      = $schema.executionModel
        inputs              = $schema.inputs
        outputs             = $schema.outputs
        executionConstraints = $schema.executionConstraints
        compatibility       = $compatibility.matrix
        compatibilityValidated = [bool]$compatibilityResult.IsCompatible
        rules               = $normalizedRules
        failureMode         = $policy.failureMode
        auditLevel          = $policy.auditLevel
        auditMetadata       = $policy.auditMetadata
        resolutionAudit     = [PSCustomObject][ordered]@{
            ContractResolved = $true
            SchemaLoaded     = $true
            VersionValidated = $true
        }
    }
}

Export-ModuleMember -Function @(
    'Resolve-ContractSchema',
    'Get-ContractDefinition',
    'Get-CompatibilityMatrix'
)
