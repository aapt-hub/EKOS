[CmdletBinding()]
param(
    [string]$TestScript = (
        Join-Path $PSScriptRoot 'Invoke-EkosRuntimeCase.ps1'
    ),

    [string]$InputPath = (
        Join-Path (Split-Path $PSScriptRoot -Parent) `
            'fixtures\input\drift.case.json'
    )
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$harnessRoot = Split-Path $PSScriptRoot -Parent
$runtimeRoot = Join-Path $harnessRoot 'fixtures\runtime'
$ps5Output = Join-Path $runtimeRoot 'drift.ps5.json'
$ps7Output = Join-Path $runtimeRoot 'drift.ps7.json'
$powershell5 = (Get-Command powershell.exe -ErrorAction Stop).Source
$powershell7 = (Get-Command pwsh.exe -ErrorAction Stop).Source

foreach ($outputPath in @($ps5Output, $ps7Output)) {
    if (Test-Path -LiteralPath $outputPath -PathType Leaf) {
        Remove-Item -LiteralPath $outputPath -Force
    }
}

$arguments5 = @(
    '-NoLogo',
    '-NoProfile',
    '-NonInteractive',
    '-ExecutionPolicy',
    'Bypass',
    '-File',
    $TestScript,
    '-InputPath',
    $InputPath,
    '-OutputPath',
    $ps5Output
)
$arguments7 = @(
    '-NoLogo',
    '-NoProfile',
    '-NonInteractive',
    '-File',
    $TestScript,
    '-InputPath',
    $InputPath,
    '-OutputPath',
    $ps7Output
)

$process5 = Start-Process `
    -FilePath $powershell5 `
    -ArgumentList $arguments5 `
    -Wait `
    -PassThru `
    -NoNewWindow
if ($process5.ExitCode -ne 0) {
    throw "PowerShell 5.1 parity run failed with exit code $($process5.ExitCode)."
}

$process7 = Start-Process `
    -FilePath $powershell7 `
    -ArgumentList $arguments7 `
    -Wait `
    -PassThru `
    -NoNewWindow
if ($process7.ExitCode -ne 0) {
    throw "PowerShell 7 parity run failed with exit code $($process7.ExitCode)."
}

return [PSCustomObject][ordered]@{
    PowerShell5Output = $ps5Output
    PowerShell7Output = $ps7Output
    InputPath         = $InputPath
    TestScript        = $TestScript
}
