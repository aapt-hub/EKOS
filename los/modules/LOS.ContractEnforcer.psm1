Set-StrictMode -Version Latest

function New-LosDenyResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Reason
    )

    [PSCustomObject][ordered]@{
        Success  = $false
        Decision = "DENY"
        Reason   = $Reason
    }
}

function Test-LosContractEnforcement {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $ContractId,

        [Parameter(Mandatory)]
        [string] $ContractVersion,

        [string] $ExpectedSchemaId,

        [string] $ExpectedSchemaVersion,

        [string] $RootPath = (Resolve-Path "$PSScriptRoot\..\..").Path
    )

    try {
        $contractPath = Join-Path $RootPath "los\contracts\$ContractId\$ContractVersion\contract.json"
        if (-not (Test-Path -LiteralPath $contractPath)) {
            return New-LosDenyResult -Reason "ContractNotFound"
        }

        try {
            $contractJson = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
        }
        catch {
            return New-LosDenyResult -Reason "ContractNotLoadable"
        }

        if ($null -eq $contractJson) {
            return New-LosDenyResult -Reason "ContractNotLoadable"
        }

        if ($contractJson.contractId -ne $ContractId -or $contractJson.version -ne $ContractVersion) {
            return New-LosDenyResult -Reason "ContractIdentityMismatch"
        }

        $contractHash = Get-FileHash -LiteralPath $contractPath -Algorithm SHA256

        if ([string]::IsNullOrWhiteSpace([string] $contractJson.outputSchema)) {
            return New-LosDenyResult -Reason "ContractSchemaMissing"
        }

        if ($ExpectedSchemaId -or $ExpectedSchemaVersion) {
            $expectedOutputSchema = "$ExpectedSchemaId`:$ExpectedSchemaVersion"
            if ($contractJson.outputSchema -ne $expectedOutputSchema) {
                return New-LosDenyResult -Reason "ContractSchemaIncompatible"
            }
        }

        [PSCustomObject][ordered]@{
            Success         = $true
            ContractId      = $contractJson.contractId
            ContractVersion = $contractJson.version
            ContractHash    = $contractHash.Hash.ToLowerInvariant()
            Contract        = $contractJson
            Decision        = "ALLOW"
        }
    }
    catch {
        New-LosDenyResult -Reason "ContractValidationError"
    }
}

Export-ModuleMember -Function Test-LosContractEnforcement
