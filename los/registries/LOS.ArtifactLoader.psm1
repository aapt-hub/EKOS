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

function Get-LosArtifactHash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    if (-not (Test-Path $Path)) {
        throw "LOS artifact not found: $Path"
    }

    $hash = Get-FileHash -Path $Path -Algorithm SHA256

    [PSCustomObject]@{
        Path      = (Resolve-Path $Path).Path
        Algorithm = "SHA256"
        Hash      = $hash.Hash.ToLowerInvariant()
    }
}

function Import-LosJsonArtifact {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    if (-not (Test-Path $Path)) {
        throw "LOS JSON artifact not found: $Path"
    }

    $resolved = (Resolve-Path $Path).Path
    $json = Get-Content $resolved -Raw | ConvertFrom-Json
    $hash = Get-LosArtifactHash -Path $resolved

    [PSCustomObject]@{
        Path      = $resolved
        Hash      = $hash.Hash
        Algorithm = $hash.Algorithm
        Artifact  = $json
    }
}

Export-ModuleMember -Function Get-LosArtifactHash, Import-LosJsonArtifact
