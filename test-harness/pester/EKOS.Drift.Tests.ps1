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
$repositoryRoot = Split-Path $harnessRoot -Parent
$moduleManifest = Join-Path $repositoryRoot 'graph\tools\EKOS.DriftEvaluator.psd1'
$fixturePath = Join-Path $harnessRoot 'fixtures\input\drift.case.json'
$goldenPath = Join-Path $harnessRoot 'fixtures\golden\driftReport.golden.json'

. (Join-Path $harnessRoot 'assertions\Assert-EkosGoldenMatch.ps1')
. (Join-Path $harnessRoot 'assertions\Assert-EkosDeterminism.ps1')

Import-Module $moduleManifest -Force -ErrorAction Stop

Describe 'EKOS deterministic drift audit' {
    It 'has the external v1.1 drift evaluator available' {
        InModuleScope EKOS.DriftEvaluator {
            (Get-Command Invoke-EkosDriftEvaluatorV1_1).CommandType |
                Should Be 'Alias'
        }
    }

    It 'matches the golden drift report' {
        $fixture = Get-Content -LiteralPath $fixturePath -Raw |
            ConvertFrom-Json
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

        (Assert-EkosGoldenMatch `
            -RuntimeObject $runtime `
            -GoldenPath $goldenPath).IsMatch | Should Be $true
    }

    It 'is deterministic after timestamp isolation' {
        $fixture = Get-Content -LiteralPath $fixturePath -Raw |
            ConvertFrom-Json

        $assertion = Assert-EkosDeterminism -ScriptBlock {
            $audit = Invoke-EkosGraphAudit `
                -SnapshotA @($fixture.SnapshotA) `
                -SnapshotB @($fixture.SnapshotB)
            $audit.TimestampUtc = 'STATIC'
            return $audit
        }

        $assertion.IsDeterministic | Should Be $true
    }
}
