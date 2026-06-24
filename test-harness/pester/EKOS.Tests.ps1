Set-StrictMode -Version Latest

$harnessRoot = Split-Path $PSScriptRoot -Parent
$repositoryRoot = Split-Path $harnessRoot -Parent
$moduleManifest = Join-Path $repositoryRoot 'graph\tools\EKOS.DriftEvaluator.psd1'
$identityScript = Join-Path $repositoryRoot 'graph\tools\EKOS.IdentityStabilizer.v2.ps1'

Describe 'EKOS module sanity' {
    It 'loads EKOS.DriftEvaluator and exports only Invoke-EkosGraphAudit' {
        Import-Module $moduleManifest -Force -ErrorAction Stop
        $commands = @(Get-Command -Module EKOS.DriftEvaluator)

        $commands.Count | Should Be 1
        $commands[0].Name | Should Be 'Invoke-EkosGraphAudit'
    }

    It 'returns the stable graph audit schema when the evaluator is unavailable' {
        Import-Module $moduleManifest -Force -ErrorAction Stop
        $result = Invoke-EkosGraphAudit -SnapshotA @() -SnapshotB @()
        $properties = @($result.PSObject.Properties.Name)

        ($properties -join ',') |
            Should Be 'TimestampUtc,Summary,Details,IsClean'
        $result.IsClean | Should Be $false
    }

    It 'loads the EKOS IdentityStabilizer command surface' {
        . $identityScript
        (Get-Command Invoke-EKOSIdentityStabilizerV2).Name |
            Should Be 'Invoke-EKOSIdentityStabilizerV2'
    }
}
