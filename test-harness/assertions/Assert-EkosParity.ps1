Set-StrictMode -Version Latest

. (Join-Path (Split-Path $PSScriptRoot -Parent) 'utils\ConvertTo-CanonicalJson.ps1')
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'utils\Compare-DeepObject.ps1')

function Assert-EkosParity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PowerShell5OutputPath,

        [Parameter(Mandatory)]
        [string]$PowerShell7OutputPath
    )

    $ps5 = Get-Content -LiteralPath $PowerShell5OutputPath -Raw |
        ConvertFrom-Json
    $ps7 = Get-Content -LiteralPath $PowerShell7OutputPath -Raw |
        ConvertFrom-Json

    $ps5Canonical = ConvertTo-CanonicalJson -InputObject $ps5
    $ps7Canonical = ConvertTo-CanonicalJson -InputObject $ps7
    $comparison = Compare-DeepObject `
        -Expected ($ps5Canonical | ConvertFrom-Json) `
        -Actual ($ps7Canonical | ConvertFrom-Json)

    if (-not $comparison.Equal) {
        $diff = [PSCustomObject][ordered]@{
            IsMatch     = $false
            PowerShell5 = $ps5
            PowerShell7 = $ps7
            Differences = $comparison.Differences
        }
        Write-Output $diff
        throw 'EKOS parity assertion failed.'
    }

    return [PSCustomObject][ordered]@{
        IsMatch     = $true
        Differences = @()
    }
}
