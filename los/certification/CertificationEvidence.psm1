Set-StrictMode -Version Latest

function New-LOSCertificationEvidence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $ExecutionId,

        [Parameter(Mandatory)]
        [string] $ContractId,

        [Parameter(Mandatory)]
        [string] $ContractVersion,

        [Parameter(Mandatory)]
        [string] $Runtime,

        [Parameter(Mandatory)]
        [object] $Input,

        [Parameter(Mandatory)]
        [object] $Output,

        [Parameter(Mandatory)]
        [object] $Schema,

        [Parameter(Mandatory)]
        [string] $ExecutionPath,

        [Parameter(Mandatory)]
        [string] $GovernanceReportHash,

        [Parameter(Mandatory)]
        [string] $DeterministicSignature,

        [Parameter(Mandatory)]
        [string] $TimestampUtc,

        [Parameter(Mandatory)]
        [string] $CertificationId,

        [Parameter()]
        [string] $EvidenceVersion = "1.0.0",

        [Parameter()]
        [string] $RepoRoot = ""
    )

    # RepoRoot may be empty depending on test/module execution context.
    # Fall back to resolving from this module's location.
    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\.." )).Path
    }

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        throw "RepoRoot is empty; cannot import canonical serializer."
    }

    $serializerPath = Join-Path $RepoRoot "graph\\tools\\EKOS.CanonicalSerializer.psm1"
    if (-not (Test-Path -LiteralPath $serializerPath)) {
        throw "Canonical serializer module not found at: $serializerPath"
    }

    Import-Module $serializerPath -Force -Global

    if (-not (Get-Command ConvertTo-EkosCanonicalJson -ErrorAction SilentlyContinue)) {
        throw "Canonical serializer did not export ConvertTo-EkosCanonicalJson"
    }

    $inputJson = ConvertTo-EkosCanonicalJson -InputObject $Input
    $outputJson = ConvertTo-EkosCanonicalJson -InputObject $Output
    $schemaJson = ConvertTo-EkosCanonicalJson -InputObject $Schema
    $pathJson = ConvertTo-EkosCanonicalJson -InputObject $ExecutionPath

    $sha = [System.Security.Cryptography.SHA256]::Create()

    $inputHashBytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($inputJson))
    $outputHashBytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($outputJson))
    $schemaHashBytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($schemaJson))
    $executionPathHashBytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($pathJson))

    $shaToHex = {
        param([byte[]]$bytes)
        return ([System.BitConverter]::ToString($bytes) -replace '-', '').ToLowerInvariant()
    }

    $evidence = [PSCustomObject][ordered]@{
        CertificationId          = $CertificationId
        ExecutionId              = $ExecutionId
        TimestampUtc            = $TimestampUtc
        ContractId              = $ContractId
        ContractVersion         = $ContractVersion
        Runtime                  = $Runtime
        InputHash                = $shaToHex.Invoke($inputHashBytes)
        OutputHash               = $shaToHex.Invoke($outputHashBytes)
        SchemaHash               = $shaToHex.Invoke($schemaHashBytes)
        ExecutionPathHash       = $shaToHex.Invoke($executionPathHashBytes)

        DeterministicSignature  = $DeterministicSignature
        GovernanceReportHash    = $GovernanceReportHash
        ComplianceStatus        = "PENDING"
        ParityStatus            = "PENDING"
        EvidenceVersion         = $EvidenceVersion
    }

    return $evidence
}

Export-ModuleMember -Function New-LOSCertificationEvidence

