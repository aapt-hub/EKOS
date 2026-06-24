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

function New-LosComplianceReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $BrokerResult,

        [string] $GeneratedUtc = (Get-Date).ToUniversalTime().ToString("o")
    )

    $contractCoverage = $false
    $schemaCoverage = $false
    $attestationCoverage = $false
    $policyCoverage = $false
    $brokerCoverage = $false

    if ($null -ne $BrokerResult) {
        $brokerCoverage = ($BrokerResult.PSObject.Properties.Name -contains "Decision" -and $BrokerResult.Decision -in @("ALLOW", "DENY"))

        if ($BrokerResult.PSObject.Properties.Name -contains "Contract" -and $null -ne $BrokerResult.Contract) {
            $contractCoverage = ($BrokerResult.Contract.PSObject.Properties.Name -contains "Success" -and $BrokerResult.Contract.Success -eq $true)
        }

        if ($BrokerResult.PSObject.Properties.Name -contains "Schema" -and $null -ne $BrokerResult.Schema) {
            $schemaCoverage = ($BrokerResult.Schema.PSObject.Properties.Name -contains "Success" -and $BrokerResult.Schema.Success -eq $true)
        }

        if ($BrokerResult.PSObject.Properties.Name -contains "Attestation" -and $null -ne $BrokerResult.Attestation) {
            $attestationCoverage = ($BrokerResult.Attestation.PSObject.Properties.Name -contains "Success" -and $BrokerResult.Attestation.Success -eq $true)
        }

        if ($BrokerResult.PSObject.Properties.Name -contains "Policy" -and $null -ne $BrokerResult.Policy) {
            $policyCoverage = ($BrokerResult.Policy.PSObject.Properties.Name -contains "Success" -and $BrokerResult.Policy.Success -eq $true)
        }
    }

    $report = [PSCustomObject][ordered]@{
        GeneratedUtc = $GeneratedUtc
        Decision     = if ($null -ne $BrokerResult -and $BrokerResult.PSObject.Properties.Name -contains "Decision") { $BrokerResult.Decision } else { "DENY" }
        Coverage     = [PSCustomObject][ordered]@{
            ContractCoverage    = $contractCoverage
            SchemaCoverage      = $schemaCoverage
            AttestationCoverage = $attestationCoverage
            PolicyCoverage      = $policyCoverage
            BrokerCoverage      = $brokerCoverage
        }
    }

    $report | ConvertTo-Json -Depth 8
}

Export-ModuleMember -Function New-LosComplianceReport
