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

function Format-EkosCanonicalScalar {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return 'null'
    }

    if ($Value -is [string] -or $Value -is [char]) {
        $encodedString = ConvertTo-Json `
            -InputObject ([string]$Value) `
            -Compress

        $encodedString = $encodedString.Replace('&', '\u0026')
        $encodedString = $encodedString.Replace("'", '\u0027')
        $encodedString = $encodedString.Replace('<', '\u003c')
        $encodedString = $encodedString.Replace('>', '\u003e')
        return $encodedString
    }

    if ($Value -is [bool]) {
        if ($Value) {
            return 'true'
        }
        return 'false'
    }

    if ($Value -is [datetime]) {
        $dateTime = [datetime]$Value
        if ($dateTime.Kind -eq [System.DateTimeKind]::Unspecified) {
            $dateTime = [datetime]::SpecifyKind(
                $dateTime,
                [System.DateTimeKind]::Utc
            )
        }
        else {
            $dateTime = $dateTime.ToUniversalTime()
        }

        $formattedDateTime = $dateTime.ToString(
            "yyyy-MM-dd'T'HH:mm:ss.fffffff'Z'",
            [System.Globalization.CultureInfo]::InvariantCulture
        )
        return ConvertTo-Json -InputObject $formattedDateTime -Compress
    }

    if ($Value -is [guid]) {
        $formattedGuid = ([guid]$Value).ToString('D').ToLowerInvariant()
        return ConvertTo-Json -InputObject $formattedGuid -Compress
    }

    if ($Value.GetType().IsEnum) {
        $underlyingType = [System.Enum]::GetUnderlyingType($Value.GetType())
        $underlyingValue = [System.Convert]::ChangeType(
            $Value,
            $underlyingType,
            [System.Globalization.CultureInfo]::InvariantCulture
        )
        return Format-EkosCanonicalScalar -Value $underlyingValue
    }

    if ($Value -is [byte] -or
        $Value -is [sbyte] -or
        $Value -is [int16] -or
        $Value -is [uint16] -or
        $Value -is [int32] -or
        $Value -is [uint32] -or
        $Value -is [int64] -or
        $Value -is [uint64]) {
        return ([System.IFormattable]$Value).ToString(
            $null,
            [System.Globalization.CultureInfo]::InvariantCulture
        )
    }

    if ($Value -is [decimal]) {
        $number = [decimal]$Value
        if ($number -eq [decimal]::Truncate($number)) {
            return $number.ToString(
                '0',
                [System.Globalization.CultureInfo]::InvariantCulture
            )
        }

        return $number.ToString(
            'G29',
            [System.Globalization.CultureInfo]::InvariantCulture
        ).Replace('E', 'e')
    }

    if ($Value -is [double] -or $Value -is [single]) {
        $number = [double]$Value
        if ([double]::IsNaN($number) -or [double]::IsInfinity($number)) {
            throw 'Non-finite floating-point values cannot be represented in canonical JSON.'
        }

        if ($number -eq 0) {
            return '0'
        }

        if ($number -eq [System.Math]::Truncate($number)) {
            return $number.ToString(
                '0',
                [System.Globalization.CultureInfo]::InvariantCulture
            )
        }

        $format = if ($Value -is [single]) { 'R' } else { 'R' }
        $formattedNumber = $number.ToString(
            $format,
            [System.Globalization.CultureInfo]::InvariantCulture
        ).Replace('E', 'e')

        if ($formattedNumber -match '^(?<mantissa>.+)e(?<sign>[+-]?)(?<digits>\d+)$') {
            $exponentDigits = $Matches['digits'].TrimStart('0')
            if ([string]::IsNullOrEmpty($exponentDigits)) {
                $exponentDigits = '0'
            }

            $exponentSign = $Matches['sign']
            if ($exponentSign -eq '+') {
                $exponentSign = ''
            }

            $formattedNumber = (
                $Matches['mantissa'] +
                'e' +
                $exponentSign +
                $exponentDigits
            )
        }

        return $formattedNumber
    }

    if ($Value.GetType().FullName -eq 'System.Numerics.BigInteger') {
        return ([System.IFormattable]$Value).ToString(
            $null,
            [System.Globalization.CultureInfo]::InvariantCulture
        )
    }

    throw "Unsupported scalar type: $($Value.GetType().FullName)"
}

function Convert-EkosOrderedObject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$InputObject
    )

    $properties = [System.Collections.Generic.List[object]]::new()

    if ($InputObject -is [System.Collections.IDictionary]) {
        foreach ($entry in $InputObject.GetEnumerator()) {
            $properties.Add([PSCustomObject]@{
                Name  = [string]$entry.Key
                Value = $entry.Value
            })
        }
    }
    else {
        foreach ($property in $InputObject.PSObject.Properties) {
            if ($property.MemberType -in @(
                'Property',
                'NoteProperty',
                'AliasProperty',
                'ScriptProperty'
            )) {
                $properties.Add([PSCustomObject]@{
                    Name  = $property.Name
                    Value = $property.Value
                })
            }
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

    $parts = [System.Collections.Generic.List[string]]::new()
    $previousName = $null
    $hasPreviousName = $false

    foreach ($property in $properties) {
        $propertyName = [string]$property.Name
        if ($hasPreviousName -and
            [System.StringComparer]::Ordinal.Equals(
                $previousName,
                $propertyName
            )) {
            throw "Duplicate canonical property name: $propertyName"
        }

        $encodedName = Format-EkosCanonicalScalar -Value $propertyName
        $encodedValue = Convert-EkosCanonicalNode -Value $property.Value
        $parts.Add($encodedName + ':' + $encodedValue)

        $previousName = $propertyName
        $hasPreviousName = $true
    }

    return '{' + [string]::Join(',', $parts) + '}'
}

function Convert-EkosCanonicalNode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return Format-EkosCanonicalScalar -Value $null
    }

    if ($Value -is [string] -or
        $Value -is [char] -or
        $Value -is [bool] -or
        $Value -is [datetime] -or
        $Value -is [guid] -or
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
        $Value -is [single] -or
        $Value.GetType().IsEnum -or
        $Value.GetType().FullName -eq 'System.Numerics.BigInteger') {
        return Format-EkosCanonicalScalar -Value $Value
    }

    if ($Value -is [System.Collections.IDictionary]) {
        return Convert-EkosOrderedObject -InputObject $Value
    }

    if ($Value -is [System.Collections.IEnumerable]) {
        $items = [System.Collections.Generic.List[string]]::new()
        foreach ($item in $Value) {
            $items.Add((Convert-EkosCanonicalNode -Value $item))
        }
        return '[' + [string]::Join(',', $items) + ']'
    }

    return Convert-EkosOrderedObject -InputObject $Value
}

function ConvertTo-EkosCanonicalJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$InputObject
    )

    return Convert-EkosCanonicalNode -Value $InputObject
}

Export-ModuleMember -Function ConvertTo-EkosCanonicalJson
