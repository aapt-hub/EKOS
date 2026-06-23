Set-StrictMode -Version Latest

function New-LosGovernanceProvenance {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $ContractId,

        [Parameter(Mandatory)]
        [string] $ContractVersion,

        [Parameter(Mandatory)]
        [string] $ContractHash,

        [Parameter(Mandatory)]
        [string] $SchemaHash,

        [Parameter(Mandatory)]
        [string] $AttestationHash,

        [Parameter(Mandatory)]
        [string] $PolicyHash,

        [Parameter(Mandatory)]
        [string] $Runtime,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $InputHash,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $OutputHash,

        [Parameter(Mandatory)]
        [ValidateSet("ALLOW", "DENY")]
        [string] $Decision,

        [string] $TimestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    )

    [PSCustomObject][ordered]@{
        ContractId      = $ContractId
        ContractVersion = $ContractVersion
        ContractHash    = $ContractHash
        SchemaHash      = $SchemaHash
        AttestationHash = $AttestationHash
        PolicyHash      = $PolicyHash
        Runtime         = $Runtime
        InputHash       = $InputHash
        OutputHash      = $OutputHash
        Decision        = $Decision
        TimestampUtc    = $TimestampUtc
    }
}

Export-ModuleMember -Function New-LosGovernanceProvenance
