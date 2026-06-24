$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $here "..\..")).Path
$moduleRoot = Join-Path $repoRoot "los\modules"

Import-Module (Join-Path $moduleRoot "LOS.ContractEnforcer.psm1") -Force -Global
Import-Module (Join-Path $moduleRoot "LOS.PolicyEngine.psm1") -Force -Global
Import-Module (Join-Path $moduleRoot "LOS.ExecutionBroker.psm1") -Force -Global
Import-Module (Join-Path $moduleRoot "LOS.ProvenanceEngine.psm1") -Force -Global
Import-Module (Join-Path $moduleRoot "LOS.ComplianceReport.psm1") -Force -Global

function New-TestLosRoot {

        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("ekos-los-26-" + [guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Path $tempRoot | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $tempRoot "los") | Out-Null
        Copy-Item -Path (Join-Path $script:repoRoot "los\contracts") -Destination (Join-Path $tempRoot "los\contracts") -Recurse
        Copy-Item -Path (Join-Path $script:repoRoot "los\schemas") -Destination (Join-Path $tempRoot "los\schemas") -Recurse
        Copy-Item -Path (Join-Path $script:repoRoot "los\attestations") -Destination (Join-Path $tempRoot "los\attestations") -Recurse
        Copy-Item -Path (Join-Path $script:repoRoot "los\registries") -Destination (Join-Path $tempRoot "los\registries") -Recurse
        return $tempRoot
    }
}

Describe "LOS Phase 2.6 Governance Enforcement" {
    It "allows a valid contract" {
        $result = Test-LosContractEnforcement -ContractId "EKOS.Execute" -ContractVersion "1.0.0" -ExpectedSchemaId "execution-result" -ExpectedSchemaVersion "1.0.0" -RootPath $script:repoRoot

        $result.Success | Should -Be $true
        $result.Decision | Should -Be "ALLOW"
        $result.ContractId | Should -Be "EKOS.Execute"
        $result.ContractVersion | Should -Be "1.0.0"
        [string]::IsNullOrWhiteSpace($result.ContractHash) | Should -Be $false
    }

    It "denies a missing contract" {
        $result = Test-LosContractEnforcement -ContractId "EKOS.Missing" -ContractVersion "1.0.0" -RootPath $script:repoRoot

        $result.Success | Should -Be $false
        $result.Decision | Should -Be "DENY"
        $result.Reason | Should -Be "ContractNotFound"
    }

    It "denies a missing schema through the broker" {
        $tempRoot = New-TestLosRoot
        try {
            Remove-Item -LiteralPath (Join-Path $tempRoot "los\schemas\execution-result") -Recurse -Force
            $result = Invoke-LosExecutionBroker -ContractId "EKOS.Execute" -ContractVersion "1.0.0" -Runtime "PS7" -RootPath $tempRoot

            $result.Success | Should -Be $false
            $result.Decision | Should -Be "DENY"
            $result.Reason | Should -Be "SchemaNotFound"
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "denies a missing attestation through the broker" {
        $tempRoot = New-TestLosRoot
        try {
            Remove-Item -LiteralPath (Join-Path $tempRoot "los\attestations\contract\EKOS.Execute") -Recurse -Force
            $result = Invoke-LosExecutionBroker -ContractId "EKOS.Execute" -ContractVersion "1.0.0" -Runtime "PS7" -RootPath $tempRoot

            $result.Success | Should -Be $false
            $result.Decision | Should -Be "DENY"
            $result.Reason | Should -Be "AttestationNotFound"
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    It "denies policy failures" {
        Import-Module (Join-Path $script:moduleRoot "LOS.PolicyEngine.psm1") -Force -Global

        $contract = [PSCustomObject]@{
            contractId    = "EKOS.Execute"
            version       = "1.0.0"
            outputSchema  = "execution-result:1.0.0"
            runtime       = @("PS5")
            deterministic = $true
        }

        $result = Invoke-LosPolicyEvaluation -Contract $contract -Runtime "PS7"

        $result.Success | Should -Be $false
        $result.Decision | Should -Be "DENY"
        $result.Reason | Should -Be "RuntimeNotAuthorized"
    }

    It "denies broker execution when any gate fails" {
        $result = Invoke-LosExecutionBroker -ContractId "EKOS.Missing" -ContractVersion "1.0.0" -Runtime "PS7" -RootPath $script:repoRoot

        $result.Success | Should -Be $false
        $result.Decision | Should -Be "DENY"
    }

    It "allows broker execution when all gates pass" {
        $result = Invoke-LosExecutionBroker `
            -ContractId "EKOS.Execute" `
            -ContractVersion "1.0.0" `
            -Runtime "PS7" `
            -InputHash "input-hash" `
            -OutputHash "output-hash" `
            -TimestampUtc "2026-06-23T00:00:00.0000000Z" `
            -RootPath $script:repoRoot

        $result.Success | Should -Be $true
        $result.Decision | Should -Be "ALLOW"
        $result.Contract.Decision | Should -Be "ALLOW"
        $result.Schema.Decision | Should -Be "ALLOW"
        $result.Attestation.Decision | Should -Be "ALLOW"
        $result.Policy.Decision | Should -Be "ALLOW"
        $result.Provenance.Decision | Should -Be "ALLOW"
    }

    It "generates canonical provenance without certification fields" {
        Import-Module (Join-Path $script:moduleRoot "LOS.ProvenanceEngine.psm1") -Force -Global

        $provenance = New-LosGovernanceProvenance `
            -ContractId "EKOS.Execute" `
            -ContractVersion "1.0.0" `
            -ContractHash "contract-hash" `
            -SchemaHash "schema-hash" `
            -AttestationHash "attestation-hash" `
            -PolicyHash "policy-hash" `
            -Runtime "PS7" `
            -InputHash "input-hash" `
            -OutputHash "output-hash" `
            -Decision "ALLOW" `
            -TimestampUtc "2026-06-23T00:00:00.0000000Z"

        $provenance.PSObject.Properties.Name -join "," | Should -Be "ContractId,ContractVersion,ContractHash,SchemaHash,AttestationHash,PolicyHash,Runtime,InputHash,OutputHash,Decision,TimestampUtc"
        $provenance.PSObject.Properties.Name -contains "Certification" | Should -Be $false
    }

    It "emits structured JSON compliance reports" {
        Import-Module (Join-Path $script:moduleRoot "LOS.ExecutionBroker.psm1") -Force -Global
        Import-Module (Join-Path $script:moduleRoot "LOS.ComplianceReport.psm1") -Force -Global

        $brokerResult = Invoke-LosExecutionBroker -ContractId "EKOS.Execute" -ContractVersion "1.0.0" -Runtime "PS7" -TimestampUtc "2026-06-23T00:00:00.0000000Z" -RootPath $script:repoRoot
        $json = New-LosComplianceReport -BrokerResult $brokerResult -GeneratedUtc "2026-06-23T00:00:00.0000000Z"
        $report = $json | ConvertFrom-Json

        $report.Decision | Should -Be "ALLOW"
        $report.Coverage.ContractCoverage | Should -Be $true
        $report.Coverage.SchemaCoverage | Should -Be $true
        $report.Coverage.AttestationCoverage | Should -Be $true
        $report.Coverage.PolicyCoverage | Should -Be $true
        $report.Coverage.BrokerCoverage | Should -Be $true
    }
}


