[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$InputPath,

    [Parameter(Mandatory)]
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$harnessRoot = Split-Path $PSScriptRoot -Parent
$repositoryRoot = Split-Path $harnessRoot -Parent
$canonicalJsonScript = Join-Path $harnessRoot 'utils\ConvertTo-CanonicalJson.ps1'
$moduleManifest = Join-Path $repositoryRoot 'graph\tools\EKOS.DriftEvaluator.psd1'

. $canonicalJsonScript
Import-Module $moduleManifest -Force -ErrorAction Stop

$fixture = Get-Content -LiteralPath $InputPath -Raw | ConvertFrom-Json
$audit = Invoke-EkosGraphAudit `
    -SnapshotA @($fixture.SnapshotA) `
    -SnapshotB @($fixture.SnapshotB)
$audit.TimestampUtc = 'STATIC'

$runtime = [PSCustomObject][ordered]@{
    SchemaVersion = [string]$fixture.SchemaVersion
    TimestampUtc   = 'STATIC'
    RootHash       = [string]$fixture.RootHash
    SnapshotA      = @($fixture.SnapshotA)
    SnapshotB      = @($fixture.SnapshotB)
    ExpectedDrift  = $audit
}

$json = ConvertTo-CanonicalJson -InputObject $runtime
[System.IO.File]::WriteAllText(
    $OutputPath,
    $json + [Environment]::NewLine,
    [System.Text.UTF8Encoding]::new($false)
)
