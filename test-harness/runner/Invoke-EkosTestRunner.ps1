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

[CmdletBinding()]
param(
    [switch]$Parity,
    [switch]$Golden,
    [switch]$Drift
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$harnessRoot = Split-Path $PSScriptRoot -Parent
$pesterRoot = Join-Path $harnessRoot 'pester'
$selected = [System.Collections.Generic.List[string]]::new()

if (-not ($Parity -or $Golden -or $Drift)) {
    $selected.Add((Join-Path $pesterRoot 'EKOS.Tests.ps1'))
    $selected.Add((Join-Path $pesterRoot 'EKOS.Drift.Tests.ps1'))
    $selected.Add((Join-Path $pesterRoot 'EKOS.Parity.Tests.ps1'))
}
else {
    $selected.Add((Join-Path $pesterRoot 'EKOS.Tests.ps1'))
    if ($Golden -or $Drift) {
        $selected.Add((Join-Path $pesterRoot 'EKOS.Drift.Tests.ps1'))
    }
    if ($Parity) {
        $selected.Add((Join-Path $pesterRoot 'EKOS.Parity.Tests.ps1'))
    }
}

$pester = Get-Module -ListAvailable Pester |
    Sort-Object Version -Descending |
    Select-Object -First 1
if ($null -eq $pester) {
    throw 'Pester is required but is not installed.'
}

Import-Module Pester -MinimumVersion $pester.Version -Force

if ($pester.Version.Major -ge 5) {
    $configuration = New-PesterConfiguration
    $configuration.Run.Path = $selected.ToArray()
    $configuration.Run.PassThru = $true
    $configuration.Output.Verbosity = 'Detailed'
    $result = Invoke-Pester -Configuration $configuration
}
else {
    $result = Invoke-Pester `
        -Script $selected.ToArray() `
        -PassThru `
        -Verbose
}

if ($result.FailedCount -gt 0) {
    throw "EKOS test harness failed: $($result.FailedCount) test(s) failed."
}

return $result
