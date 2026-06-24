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

function ConvertTo-CanonicalJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowNull()]
        [object]$InputObject,

        [ValidateRange(2, 100)]
        [int]$Depth = 100,

        [switch]$RemoveNullProperties
    )

    begin {
        function ConvertTo-CanonicalValue {
            param(
                [AllowNull()]
                [object]$Value
            )

            if ($null -eq $Value) {
                return $null
            }

            if ($Value -is [string] -or
                $Value -is [char] -or
                $Value -is [bool] -or
                $Value -is [byte] -or
                $Value -is [sbyte] -or
                $Value -is [int16] -or
                $Value -is [uint16] -or
                $Value -is [int32] -or
                $Value -is [uint32] -or
                $Value -is [int64] -or
                $Value -is [uint64] -or
                $Value -is [single] -or
                $Value -is [double] -or
                $Value -is [decimal]) {
                return $Value
            }

            if ($Value -is [datetime]) {
                return $Value.ToUniversalTime().ToString(
                    'o',
                    [System.Globalization.CultureInfo]::InvariantCulture
                )
            }

            if ($Value -is [System.Collections.IDictionary]) {
                $names = [System.Collections.Generic.List[string]]::new()
                foreach ($key in $Value.Keys) {
                    $names.Add([string]$key)
                }
                $names.Sort([System.StringComparer]::Ordinal)

                $ordered = [ordered]@{}
                foreach ($name in $names) {
                    $propertyValue = $Value[$name]
                    if ($RemoveNullProperties -and $null -eq $propertyValue) {
                        continue
                    }
                    $ordered[$name] = ConvertTo-CanonicalValue -Value $propertyValue
                }
                return [PSCustomObject]$ordered
            }

            if ($Value -is [System.Collections.IEnumerable] -and
                $Value -isnot [string]) {
                $items = [System.Collections.Generic.List[object]]::new()
                foreach ($item in $Value) {
                    $items.Add((ConvertTo-CanonicalValue -Value $item))
                }

                $items.Sort(
                    [System.Comparison[object]]{
                        param($left, $right)
                        $leftJson = $left | ConvertTo-Json -Depth 100 -Compress
                        $rightJson = $right | ConvertTo-Json -Depth 100 -Compress
                        return [System.StringComparer]::Ordinal.Compare(
                            $leftJson,
                            $rightJson
                        )
                    }
                )
                return ,$items.ToArray()
            }

            $propertyNames = [System.Collections.Generic.List[string]]::new()
            foreach ($property in $Value.PSObject.Properties) {
                if ($property.MemberType -in @(
                    'Property',
                    'NoteProperty',
                    'AliasProperty',
                    'ScriptProperty'
                )) {
                    $propertyNames.Add($property.Name)
                }
            }
            $propertyNames.Sort([System.StringComparer]::Ordinal)

            $result = [ordered]@{}
            foreach ($propertyName in $propertyNames) {
                $propertyValue = $Value.PSObject.Properties[$propertyName].Value
                if ($RemoveNullProperties -and $null -eq $propertyValue) {
                    continue
                }
                $result[$propertyName] = ConvertTo-CanonicalValue -Value $propertyValue
            }
            return [PSCustomObject]$result
        }
    }

    process {
        $canonical = ConvertTo-CanonicalValue -Value $InputObject
        return $canonical | ConvertTo-Json -Depth $Depth -Compress
    }
}
