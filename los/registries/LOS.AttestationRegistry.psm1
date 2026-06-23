Set-StrictMode -Version Latest

function New-LosArtifactAttestation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $ArtifactPath,

        [Parameter(Mandatory)]
        [string] $ArtifactType,

        [string] $RootPath = (Resolve-Path "$PSScriptRoot\..\..").Path
    )

    Import-Module (Join-Path $PSScriptRoot "LOS.ArtifactLoader.psm1") -Force

    $artifact = Import-LosJsonArtifact -Path $ArtifactPath

    [PSCustomObject]@{
        ArtifactType = $ArtifactType
        ArtifactPath = $artifact.Path
        HashAlgorithm = $artifact.Algorithm
        ArtifactHash = $artifact.Hash
        AttestedUtc = (Get-Date).ToUniversalTime().ToString("o")
        AttestationVersion = "1.0.0"
    }
}

Export-ModuleMember -Function New-LosArtifactAttestation
