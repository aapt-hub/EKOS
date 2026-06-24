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

function Get-LosContract {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $ContractId,

        [Parameter(Mandatory)]
        [string] $Version,

        [string] $RootPath = (Resolve-Path "$PSScriptRoot\..\..").Path
    )

    $contractPath = Join-Path $RootPath "los\contracts\$ContractId\$Version\contract.json"

    if (-not (Test-Path $contractPath)) {
        throw "LOS contract not found: $contractPath"
    }

    $json = Get-Content $contractPath -Raw | ConvertFrom-Json

    [PSCustomObject]@{
        ContractId = $json.contractId
        Version    = $json.version
        Path       = $contractPath
        Contract   = $json
    }
}

Export-ModuleMember -Function Get-LosContract
