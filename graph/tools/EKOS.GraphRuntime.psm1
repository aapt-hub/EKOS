Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Global:EKOS_Runtime = @{
    PSVersion = $PSVersionTable.PSVersion.ToString()
    Edition   = $PSVersionTable.PSEdition
    IsCore    = ($PSVersionTable.PSEdition -eq 'Core')
}

function Get-EkosRuntimeInfo {
    [CmdletBinding()]
    param(
        [switch]$IncludeFeatureParity
    )

    $runtime = [ordered]@{
        PSVersion = $PSVersionTable.PSVersion.ToString()
        Edition   = $PSVersionTable.PSEdition
        IsCore    = ($PSVersionTable.PSEdition -eq 'Core')
    }

    if ($IncludeFeatureParity) {
        $runtime['Runtime'] = if ($runtime.IsCore) { 'PS7' } else { 'PS5' }
        $runtime['FeatureParity'] = [ordered]@{
            HasCoreEdition              = [bool]$runtime.IsCore
            HasConvertFromJsonHashtable = (
                $PSVersionTable.PSVersion.Major -ge 6
            )
            HasNullCoalescingOperator    = (
                $PSVersionTable.PSVersion.Major -ge 7
            )
        }
    }

    return [PSCustomObject]$runtime
}

function Normalize-Null {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object]$InputObject
    )

    process {
        if ($null -eq $InputObject) {
            return $null
        }

        $psObject = $InputObject.PSObject
        if ($null -ne $psObject -and $null -eq $psObject.BaseObject) {
            return $null
        }

        Write-Output -NoEnumerate $InputObject
    }
}

function Normalize-Number {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$Number
    )

    process {
        $invariant = [System.Globalization.CultureInfo]::InvariantCulture

        if ($Number -is [byte] -or
            $Number -is [sbyte] -or
            $Number -is [int16] -or
            $Number -is [uint16] -or
            $Number -is [int32] -or
            $Number -is [uint32] -or
            $Number -is [int64]) {
            return [int64]$Number
        }

        if ($Number -is [uint64]) {
            if ([uint64]$Number -le [uint64][int64]::MaxValue) {
                return [int64]$Number
            }
            return [uint64]$Number
        }

        if ($Number -is [decimal]) {
            $canonicalDecimalText = ([decimal]$Number).ToString(
                'G29',
                $invariant
            )
            $canonicalDecimal = [decimal]::Parse(
                $canonicalDecimalText,
                [System.Globalization.NumberStyles]::Float,
                $invariant
            )

            if ($canonicalDecimal -eq [decimal]::Truncate($canonicalDecimal)) {
                if ($canonicalDecimal -ge [decimal][int64]::MinValue -and
                    $canonicalDecimal -le [decimal][int64]::MaxValue) {
                    return [int64]$canonicalDecimal
                }

                if ($canonicalDecimal -ge [decimal]0 -and
                    $canonicalDecimal -le [decimal][uint64]::MaxValue) {
                    return [uint64]$canonicalDecimal
                }
            }

            return $canonicalDecimal
        }

        if ($Number -is [single] -or $Number -is [double]) {
            $floatingPoint = [double]$Number
            if ([double]::IsNaN($floatingPoint) -or
                [double]::IsInfinity($floatingPoint)) {
                throw 'EKOS normalization does not support non-finite numbers.'
            }

            if ($floatingPoint -eq 0) {
                return [int64]0
            }

            if ($floatingPoint -eq [System.Math]::Truncate($floatingPoint)) {
                if ($floatingPoint -ge [double][int64]::MinValue -and
                    $floatingPoint -le [double][int64]::MaxValue) {
                    return [int64]$floatingPoint
                }

                if ($floatingPoint -ge 0 -and
                    $floatingPoint -le [double][uint64]::MaxValue) {
                    return [uint64]$floatingPoint
                }
            }

            $roundTripText = ([System.IFormattable]$Number).ToString(
                'R',
                $invariant
            )
            $canonicalDecimal = [decimal]0
            $parsed = [decimal]::TryParse(
                $roundTripText,
                [System.Globalization.NumberStyles]::Float,
                $invariant,
                [ref]$canonicalDecimal
            )
            if (-not $parsed) {
                throw "EKOS number is outside the deterministic decimal range: $roundTripText"
            }

            $canonicalDecimalText = $canonicalDecimal.ToString(
                'G29',
                $invariant
            )
            return [decimal]::Parse(
                $canonicalDecimalText,
                [System.Globalization.NumberStyles]::Float,
                $invariant
            )
        }

        throw "Unsupported EKOS numeric type: $($Number.GetType().FullName)"
    }
}

function ConvertTo-EkosNormalizedNode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object]$InputObject
    )

    if ($null -eq $InputObject -or
        ($null -ne $InputObject.PSObject -and
            $null -eq $InputObject.PSObject.BaseObject)) {
        return [PSCustomObject]@{ Value = $null }
    }

    if ($InputObject -is [string] -or $InputObject -is [char]) {
        return [PSCustomObject]@{
            Value = ([string]$InputObject).Normalize(
                [System.Text.NormalizationForm]::FormC
            )
        }
    }

    if ($InputObject -is [bool]) {
        return [PSCustomObject]@{ Value = [bool]$InputObject }
    }

    if ($InputObject -is [byte] -or
        $InputObject -is [sbyte] -or
        $InputObject -is [int16] -or
        $InputObject -is [uint16] -or
        $InputObject -is [int32] -or
        $InputObject -is [uint32] -or
        $InputObject -is [int64] -or
        $InputObject -is [uint64] -or
        $InputObject -is [decimal] -or
        $InputObject -is [single] -or
        $InputObject -is [double]) {
        return [PSCustomObject]@{
            Value = Normalize-Number -Number $InputObject
        }
    }

    if ($InputObject -is [datetime]) {
        $dateTime = [datetime]$InputObject
        if ($dateTime.Kind -eq [System.DateTimeKind]::Unspecified) {
            $dateTime = [datetime]::SpecifyKind(
                $dateTime,
                [System.DateTimeKind]::Utc
            )
        }
        else {
            $dateTime = $dateTime.ToUniversalTime()
        }

        return [PSCustomObject]@{
            Value = $dateTime.ToString(
                "yyyy-MM-dd'T'HH:mm:ss.fffffff'Z'",
                [System.Globalization.CultureInfo]::InvariantCulture
            )
        }
    }

    if ($InputObject -is [guid]) {
        return [PSCustomObject]@{
            Value = ([guid]$InputObject).ToString('D').ToLowerInvariant()
        }
    }

    if ($InputObject.GetType().IsEnum) {
        $underlyingType = [System.Enum]::GetUnderlyingType(
            $InputObject.GetType()
        )
        $underlyingValue = [System.Convert]::ChangeType(
            $InputObject,
            $underlyingType,
            [System.Globalization.CultureInfo]::InvariantCulture
        )
        return [PSCustomObject]@{
            Value = Normalize-Number -Number $underlyingValue
        }
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $entries = [System.Collections.Generic.List[object]]::new()
        foreach ($entry in $InputObject.GetEnumerator()) {
            $normalizedName = ([string]$entry.Key).Normalize(
                [System.Text.NormalizationForm]::FormC
            )
            $entries.Add([PSCustomObject]@{
                Name  = $normalizedName
                Value = $entry.Value
            })
        }

        $entries.Sort(
            [System.Comparison[object]]{
                param($left, $right)
                return [System.StringComparer]::Ordinal.Compare(
                    [string]$left.Name,
                    [string]$right.Name
                )
            }
        )

        $result = [ordered]@{}
        foreach ($entry in $entries) {
            if ($result.Contains([string]$entry.Name)) {
                throw "Duplicate normalized EKOS key: $($entry.Name)"
            }

            $child = ConvertTo-EkosNormalizedNode -InputObject $entry.Value
            $result[[string]$entry.Name] = $child.Value
        }

        return [PSCustomObject]@{ Value = $result }
    }

    if ($InputObject -is [System.Collections.IEnumerable]) {
        $items = [System.Collections.Generic.List[object]]::new()
        foreach ($item in $InputObject) {
            $child = ConvertTo-EkosNormalizedNode -InputObject $item
            $items.Add($child.Value)
        }
        return [PSCustomObject]@{ Value = $items.ToArray() }
    }

    $properties = [System.Collections.Generic.List[object]]::new()
    foreach ($property in $InputObject.PSObject.Properties) {
        if ($property.MemberType -in @(
            'Property',
            'NoteProperty',
            'AliasProperty'
        )) {
            $normalizedName = $property.Name.Normalize(
                [System.Text.NormalizationForm]::FormC
            )
            $properties.Add([PSCustomObject]@{
                Name  = $normalizedName
                Value = $property.Value
            })
        }
    }

    $properties.Sort(
        [System.Comparison[object]]{
            param($left, $right)
            return [System.StringComparer]::Ordinal.Compare(
                [string]$left.Name,
                [string]$right.Name
            )
        }
    )

    $normalizedObject = [ordered]@{}
    foreach ($property in $properties) {
        if ($normalizedObject.Contains([string]$property.Name)) {
            throw "Duplicate normalized EKOS property: $($property.Name)"
        }

        $child = ConvertTo-EkosNormalizedNode -InputObject $property.Value
        $normalizedObject[[string]$property.Name] = $child.Value
    }

    return [PSCustomObject]@{
        Value = [PSCustomObject]$normalizedObject
    }
}

function Normalize-Object {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object]$InputObject
    )

    process {
        $normalizedNode = ConvertTo-EkosNormalizedNode `
            -InputObject $InputObject

        if ($normalizedNode.Value -is [System.Array]) {
            Write-Output -NoEnumerate $normalizedNode.Value
            return
        }

        return $normalizedNode.Value
    }
}

function ConvertTo-EkosRuntimeJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object]$InputObject
    )

    if ($null -eq $InputObject) {
        return 'null'
    }

    $json = ConvertTo-Json `
        -InputObject $InputObject `
        -Depth 20 `
        -Compress

    $json = $json.Replace('&', '\u0026')
    $json = $json.Replace("'", '\u0027')
    $json = $json.Replace('<', '\u003c')
    $json = $json.Replace('>', '\u003e')
    return $json
}

function Invoke-EkosNormalizePipeline {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object]$InputObject,

        [switch]$AsJson
    )

    process {
        $normalizedNode = ConvertTo-EkosNormalizedNode `
            -InputObject $InputObject

        if ($AsJson) {
            return ConvertTo-EkosRuntimeJson `
                -InputObject $normalizedNode.Value
        }

        if ($normalizedNode.Value -is [System.Array]) {
            Write-Output -NoEnumerate $normalizedNode.Value
            return
        }

        return $normalizedNode.Value
    }
}

function ConvertTo-EkosCanonicalError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $exception = $ErrorRecord.Exception
    $stack = if (-not [string]::IsNullOrEmpty($ErrorRecord.ScriptStackTrace)) {
        $ErrorRecord.ScriptStackTrace
    }
    elseif ($null -ne $exception -and
        -not [string]::IsNullOrEmpty($exception.StackTrace)) {
        $exception.StackTrace
    }
    else {
        ''
    }

    $target = if ($null -eq $ErrorRecord.TargetObject) {
        ''
    }
    else {
        [System.Convert]::ToString(
            $ErrorRecord.TargetObject,
            [System.Globalization.CultureInfo]::InvariantCulture
        )
    }

    return [PSCustomObject][ordered]@{
        Type     = if ($null -eq $exception) {
            ''
        }
        else {
            $exception.GetType().FullName
        }
        Message  = if ($null -eq $exception) {
            ''
        }
        else {
            $exception.Message.Normalize(
                [System.Text.NormalizationForm]::FormC
            )
        }
        Category = [string]$ErrorRecord.CategoryInfo.Category
        Stack    = $stack.Replace("`r`n", "`n").Normalize(
            [System.Text.NormalizationForm]::FormC
        )
        Target   = $target.Normalize(
            [System.Text.NormalizationForm]::FormC
        )
        Runtime  = if ($PSVersionTable.PSEdition -eq 'Core') {
            'PS7'
        }
        else {
            'PS5'
        }
    }
}

function Invoke-EkosRuntime {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Script,

        [Parameter(Mandatory)]
        [AllowNull()]
        [hashtable]$Context
    )

    $normalizedContext = Normalize-Object -InputObject $Context

    try {
        $output = @(& $Script -Context $normalizedContext)
        if ($output.Count -eq 0) {
            return $null
        }

        if ($output.Count -eq 1) {
            return Invoke-EkosNormalizePipeline -InputObject $output[0]
        }

        return Invoke-EkosNormalizePipeline -InputObject (, $output)
    }
    catch {
        return ConvertTo-EkosCanonicalError -ErrorRecord $_
    }
}

Export-ModuleMember -Function @(
    'Invoke-EkosRuntime',
    'Invoke-EkosNormalizePipeline',
    'Normalize-Object',
    'Normalize-Null',
    'Normalize-Number',
    'ConvertTo-EkosCanonicalError',
    'Get-EkosRuntimeInfo'
)
