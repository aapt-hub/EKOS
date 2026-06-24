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

. (Join-Path (Split-Path $PSScriptRoot -Parent) 'utils\ConvertTo-CanonicalJson.ps1')
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'utils\Compare-DeepObject.ps1')

function Assert-EkosGoldenMatch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$RuntimeObject,

        [Parameter(Mandatory)]
        [string]$GoldenPath
    )

    $goldenObject = Get-Content -LiteralPath $GoldenPath -Raw |
        ConvertFrom-Json
    $goldenCanonical = ConvertTo-CanonicalJson -InputObject $goldenObject
    $runtimeCanonical = ConvertTo-CanonicalJson -InputObject $RuntimeObject
    $comparison = Compare-DeepObject `
        -Expected ($goldenCanonical | ConvertFrom-Json) `
        -Actual ($runtimeCanonical | ConvertFrom-Json)

    if (-not $comparison.Equal) {
        $diff = [PSCustomObject][ordered]@{
            IsMatch     = $false
            GoldenPath  = $GoldenPath
            Differences = $comparison.Differences
        }
        Write-Output $diff
        throw 'EKOS golden snapshot assertion failed.'
    }

    return [PSCustomObject][ordered]@{
        IsMatch     = $true
        GoldenPath  = $GoldenPath
        Differences = @()
    }
}
