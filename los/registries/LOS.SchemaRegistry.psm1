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

function Get-LosSchema {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $SchemaId,

        [Parameter(Mandatory)]
        [string] $Version,

        [string] $RootPath = (Resolve-Path "$PSScriptRoot\..\..").Path
    )

    $schemaPath = Join-Path $RootPath "los\schemas\$SchemaId\$Version\schema.json"

    if (-not (Test-Path $schemaPath)) {
        throw "LOS schema not found: $schemaPath"
    }

    $json = Get-Content $schemaPath -Raw | ConvertFrom-Json

    [PSCustomObject]@{
        SchemaId = $SchemaId
        Version  = $Version
        Path     = $schemaPath
        Schema   = $json
    }
}

Export-ModuleMember -Function Get-LosSchema
