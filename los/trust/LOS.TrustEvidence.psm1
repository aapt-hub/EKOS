Set-StrictMode -Version Latest

function Get-LOSTrustRepoRoot {
    [CmdletBinding()]
    param(
        [string] $RepoRoot = ""
    )

    if (-not [string]::IsNullOrWhiteSpace($RepoRoot)) {
        return (Resolve-Path $RepoRoot).Path
    }

    return (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
}

function Get-LOSTrustSha256 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Value
    )

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
        $hash = $sha.ComputeHash($bytes)
        return ([System.BitConverter]::ToString($hash) -replace "-", "").ToLowerInvariant()
    }
    finally {
        if ($sha -is [System.IDisposable]) {
            $sha.Dispose()
        }
    }
}

function ConvertTo-LOSTrustCanonicalJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $InputObject,

        [string] $RepoRoot = ""
    )

    $resolvedRoot = Get-LOSTrustRepoRoot -RepoRoot $RepoRoot
    $serializerPath = Join-Path $resolvedRoot "graph\tools\EKOS.CanonicalSerializer.psm1"
    if (-not (Test-Path -LiteralPath $serializerPath)) {
        throw "Canonical serializer module not found at: $serializerPath"
    }

    Import-Module $serializerPath -Force -Global
    return ConvertTo-EkosCanonicalJson -InputObject $InputObject
}

function New-LOSTrustEvidence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $TrustEvidenceId,

        [Parameter(Mandatory)]
        [string] $RuntimeId,

        [Parameter(Mandatory)]
        [string] $RuntimeVersion,

        [Parameter(Mandatory)]
        [string] $RuntimeHash,

        [Parameter(Mandatory)]
        [string] $CertificationId,

        [Parameter(Mandatory)]
        [string] $CertificationStatus,

        [Parameter(Mandatory)]
        [string] $EvidenceHash,

        [string[]] $Capabilities = @(),

        [Parameter(Mandatory)]
        [string] $TimestampUtc,

        [string] $EvidenceVersion = "1.0.0",

        [string] $RepoRoot = ""
    )

    $payload = [PSCustomObject][ordered]@{
        TrustEvidenceId     = $TrustEvidenceId
        RuntimeId           = $RuntimeId
        RuntimeVersion      = $RuntimeVersion
        RuntimeHash         = $RuntimeHash
        CertificationId     = $CertificationId
        CertificationStatus = $CertificationStatus
        EvidenceHash        = $EvidenceHash
        Capabilities        = @($Capabilities | Sort-Object)
        TimestampUtc        = $TimestampUtc
        EvidenceVersion     = $EvidenceVersion
    }

    $canonical = ConvertTo-LOSTrustCanonicalJson -InputObject $payload -RepoRoot $RepoRoot
    $trustEvidenceHash = Get-LOSTrustSha256 -Value $canonical

    return [PSCustomObject][ordered]@{
        TrustEvidenceId     = $payload.TrustEvidenceId
        RuntimeId           = $payload.RuntimeId
        RuntimeVersion      = $payload.RuntimeVersion
        RuntimeHash         = $payload.RuntimeHash
        CertificationId     = $payload.CertificationId
        CertificationStatus = $payload.CertificationStatus
        EvidenceHash        = $payload.EvidenceHash
        Capabilities        = $payload.Capabilities
        TimestampUtc        = $payload.TimestampUtc
        EvidenceVersion     = $payload.EvidenceVersion
        TrustEvidenceHash   = $trustEvidenceHash
    }
}

Export-ModuleMember -Function New-LOSTrustEvidence, ConvertTo-LOSTrustCanonicalJson, Get-LOSTrustSha256
