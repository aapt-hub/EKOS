Set-StrictMode -Version Latest

# Under Pester, $script: scope may not be reliably available when this helper is dot-sourced.
# Use a safe initialization guard that does not reference $script:repoRoot when it's unset.
if (-not (Get-Variable -Name repoRoot -Scope Script -ErrorAction SilentlyContinue)) {
    $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
}


function New-TestLosRoot {

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("ekos-los-27-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tempRoot | Out-Null

    New-Item -ItemType Directory -Path (Join-Path $tempRoot "los") | Out-Null
    Copy-Item -Path (Join-Path $repoRoot "los\\contracts") -Destination (Join-Path $tempRoot "los\\contracts") -Recurse
    Copy-Item -Path (Join-Path $repoRoot "los\\schemas") -Destination (Join-Path $tempRoot "los\\schemas") -Recurse
    Copy-Item -Path (Join-Path $repoRoot "los\\attestations") -Destination (Join-Path $tempRoot "los\\attestations") -Recurse
    Copy-Item -Path (Join-Path $repoRoot "los\\registries") -Destination (Join-Path $tempRoot "los\\registries") -Recurse

    # certification output directories for harness/ledger/report
    New-Item -ItemType Directory -Path (Join-Path $tempRoot "los\\certification-data\\ledger") | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $tempRoot "los\\certification-data\\reports") | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $tempRoot "los\\certification-data\\evidence") | Out-Null

    return $tempRoot
}

function Get-ReferenceEvidence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $certId,
        [Parameter(Mandatory)][string] $execId,
        [Parameter(Mandatory)][string] $ts
    )

    return New-LOSCertificationEvidence `
        -ExecutionId $execId `
        -ContractId "EKOS.Execute" `
        -ContractVersion "1.0.0" `
        -Runtime "PS7" `
        -Input @{ a = 1; b = @('x','y') } `
        -Output @{ ok = $true } `
        -Schema @{ type = "object" } `
        -ExecutionPath "EKOS.Execute->PS7" `
        -GovernanceReportHash "gov-hash" `
        -DeterministicSignature "sig-1" `
        -TimestampUtc $ts `
        -CertificationId $certId `
        -EvidenceVersion "1.0.0" `
        -RepoRoot $repoRoot
}

