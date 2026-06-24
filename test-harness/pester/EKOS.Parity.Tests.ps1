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

$harnessRoot = Split-Path $PSScriptRoot -Parent
$parityRunner = Join-Path $harnessRoot 'runner\Invoke-EkosParityRunner.ps1'
$parityAssertion = Join-Path $harnessRoot 'assertions\Assert-EkosParity.ps1'

. $parityAssertion

Describe 'EKOS PowerShell runtime parity' {
    It 'produces structurally identical output in PowerShell 5.1 and 7' {
        $run = & $parityRunner
        $assertion = Assert-EkosParity `
            -PowerShell5OutputPath $run.PowerShell5Output `
            -PowerShell7OutputPath $run.PowerShell7Output

        $assertion.IsMatch | Should Be $true
    }
}
