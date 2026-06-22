Set-StrictMode -Version Latest

function Compare-DeepObject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Expected,

        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Actual
    )

    $differences = [System.Collections.Generic.List[object]]::new()

    function Add-DeepDifference {
        param(
            [string]$Path,
            [AllowNull()][object]$ExpectedValue,
            [AllowNull()][object]$ActualValue,
            [string]$Reason
        )

        $differences.Add([PSCustomObject][ordered]@{
            Path     = $Path
            Expected = $ExpectedValue
            Actual   = $ActualValue
            Reason   = $Reason
        })
    }

    function Get-ComparableProperties {
        param([object]$Value)

        $names = [System.Collections.Generic.List[string]]::new()
        if ($Value -is [System.Collections.IDictionary]) {
            foreach ($key in $Value.Keys) {
                $names.Add([string]$key)
            }
        }
        else {
            foreach ($property in $Value.PSObject.Properties) {
                if ($property.MemberType -in @(
                    'Property',
                    'NoteProperty',
                    'AliasProperty',
                    'ScriptProperty'
                )) {
                    $names.Add($property.Name)
                }
            }
        }

        $names.Sort([System.StringComparer]::Ordinal)
        return $names.ToArray()
    }

    function Get-ComparablePropertyValue {
        param(
            [object]$Value,
            [string]$Name
        )

        if ($Value -is [System.Collections.IDictionary]) {
            return $Value[$Name]
        }
        return $Value.PSObject.Properties[$Name].Value
    }

    function Test-IsScalar {
        param([AllowNull()][object]$Value)

        return (
            $null -eq $Value -or
            $Value -is [string] -or
            $Value -is [char] -or
            $Value -is [bool] -or
            $Value -is [ValueType]
        )
    }

    function Compare-DeepValue {
        param(
            [AllowNull()][object]$ExpectedValue,
            [AllowNull()][object]$ActualValue,
            [string]$Path
        )

        if ($null -eq $ExpectedValue -or $null -eq $ActualValue) {
            if ($null -ne $ExpectedValue -or $null -ne $ActualValue) {
                Add-DeepDifference $Path $ExpectedValue $ActualValue 'NullMismatch'
            }
            return
        }

        if ((Test-IsScalar $ExpectedValue) -and (Test-IsScalar $ActualValue)) {
            if ([System.StringComparer]::Ordinal.Compare(
                [string]$ExpectedValue,
                [string]$ActualValue
            ) -ne 0) {
                Add-DeepDifference $Path $ExpectedValue $ActualValue 'ValueMismatch'
            }
            return
        }

        $expectedEnumerable = (
            $ExpectedValue -is [System.Collections.IEnumerable] -and
            $ExpectedValue -isnot [string] -and
            $ExpectedValue -isnot [System.Collections.IDictionary]
        )
        $actualEnumerable = (
            $ActualValue -is [System.Collections.IEnumerable] -and
            $ActualValue -isnot [string] -and
            $ActualValue -isnot [System.Collections.IDictionary]
        )

        if ($expectedEnumerable -or $actualEnumerable) {
            if (-not ($expectedEnumerable -and $actualEnumerable)) {
                Add-DeepDifference $Path $ExpectedValue $ActualValue 'TypeMismatch'
                return
            }

            $expectedItems = @($ExpectedValue)
            $actualItems = @($ActualValue)
            if ($expectedItems.Count -ne $actualItems.Count) {
                Add-DeepDifference $Path $expectedItems.Count $actualItems.Count 'CountMismatch'
                return
            }

            for ($index = 0; $index -lt $expectedItems.Count; $index++) {
                Compare-DeepValue `
                    -ExpectedValue $expectedItems[$index] `
                    -ActualValue $actualItems[$index] `
                    -Path "$Path[$index]"
            }
            return
        }

        $expectedNames = @(Get-ComparableProperties -Value $ExpectedValue)
        $actualNames = @(Get-ComparableProperties -Value $ActualValue)

        if (($expectedNames -join "`0") -cne ($actualNames -join "`0")) {
            Add-DeepDifference $Path $expectedNames $actualNames 'PropertyMismatch'
            return
        }

        foreach ($name in $expectedNames) {
            Compare-DeepValue `
                -ExpectedValue (Get-ComparablePropertyValue $ExpectedValue $name) `
                -ActualValue (Get-ComparablePropertyValue $ActualValue $name) `
                -Path "$Path.$name"
        }
    }

    Compare-DeepValue -ExpectedValue $Expected -ActualValue $Actual -Path '$'

    return [PSCustomObject][ordered]@{
        Equal       = ($differences.Count -eq 0)
        Differences = $differences.ToArray()
    }
}
