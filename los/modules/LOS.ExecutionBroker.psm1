Set-StrictMode -Version Latest

function New-LosBrokerDenyResult {
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

function Split-LosSchemaReference {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $SchemaReference
    )

    $parts = $SchemaReference -split ":", 2
    if ($parts.Count -ne 2 -or [string]::IsNullOrWhiteSpace($parts[0]) -or [string]::IsNullOrWhiteSpace($parts[1])) {
        throw "Invalid schema reference: $SchemaReference"
    }

    [PSCustomObject][ordered]@{
        SchemaId      = $parts[0]
        SchemaVersion = $parts[1]
    }
}

function Test-LosSchemaGate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $SchemaId,

        [Parameter(Mandatory)]
        [string] $SchemaVersion,

        [Parameter(Mandatory)]
        [string] $RootPath
    )

    try {
        $schemaPath = Join-Path $RootPath "los\schemas\$SchemaId\$SchemaVersion\schema.json"
        if (-not (Test-Path -LiteralPath $schemaPath)) {
            return New-LosBrokerDenyResult -Reason "SchemaNotFound"
        }

        try {
            $schemaJson = Get-Content -LiteralPath $schemaPath -Raw | ConvertFrom-Json
        }
        catch {
            return New-LosBrokerDenyResult -Reason "SchemaNotLoadable"
        }

        if ($null -eq $schemaJson) {
            return New-LosBrokerDenyResult -Reason "SchemaNotLoadable"
        }

        if (-not ($schemaJson.PSObject.Properties.Name -contains "type") -or $schemaJson.type -ne "object") {
            return New-LosBrokerDenyResult -Reason "SchemaInvalid"
        }

        $schemaHash = Get-FileHash -LiteralPath $schemaPath -Algorithm SHA256

        [PSCustomObject][ordered]@{
            Success       = $true
            SchemaId      = $SchemaId
            SchemaVersion = $SchemaVersion
            SchemaHash    = $schemaHash.Hash.ToLowerInvariant()
            Decision      = "ALLOW"
        }
    }
    catch {
        New-LosBrokerDenyResult -Reason "SchemaValidationError"
    }
}

function Test-LosAttestationGate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $ContractId,

        [Parameter(Mandatory)]
        [string] $ContractVersion,

        [Parameter(Mandatory)]
        [string] $ContractHash,

        [Parameter(Mandatory)]
        [string] $RootPath
    )

    try {
        $attestationPath = Join-Path $RootPath "los\attestations\contract\$ContractId\$ContractVersion\attestation.json"
        if (-not (Test-Path -LiteralPath $attestationPath)) {
            return New-LosBrokerDenyResult -Reason "AttestationNotFound"
        }

        try {
            $attestationJson = Get-Content -LiteralPath $attestationPath -Raw | ConvertFrom-Json
        }
        catch {
            return New-LosBrokerDenyResult -Reason "AttestationNotLoadable"
        }

        if ($attestationJson.ArtifactType -ne "contract") {
            return New-LosBrokerDenyResult -Reason "AttestationInvalid"
        }

        if ($attestationJson.ArtifactHash -ne $ContractHash) {
            return New-LosBrokerDenyResult -Reason "AttestationHashMismatch"
        }

        $attestationHash = Get-FileHash -LiteralPath $attestationPath -Algorithm SHA256

        [PSCustomObject][ordered]@{
            Success         = $true
            AttestationHash = $attestationHash.Hash.ToLowerInvariant()
            Decision        = "ALLOW"
        }
    }
    catch {
        New-LosBrokerDenyResult -Reason "AttestationValidationError"
    }
}

function Invoke-LosExecutionBroker {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $ContractId,

        [Parameter(Mandatory)]
        [string] $ContractVersion,

        [Parameter(Mandatory)]
        [string] $Runtime,

        [hashtable] $ExecutionContext = @{},

        [string[]] $RequiredCapabilities = @(),

        [string] $InputHash = "",

        [string] $OutputHash = "",

        [string] $TimestampUtc = (Get-Date).ToUniversalTime().ToString("o"),

        [string] $RootPath = (Resolve-Path "$PSScriptRoot\..\..").Path
    )

    try {
        Import-Module (Join-Path $PSScriptRoot "LOS.ContractEnforcer.psm1") -Force -Global
        Import-Module (Join-Path $PSScriptRoot "LOS.PolicyEngine.psm1") -Force -Global
        Import-Module (Join-Path $PSScriptRoot "LOS.ProvenanceEngine.psm1") -Force -Global

        $contractCommand = Get-Command -Name Test-LosContractEnforcement -ErrorAction Stop
        $policyCommand = Get-Command -Name Invoke-LosPolicyEvaluation -ErrorAction Stop
        $provenanceCommand = Get-Command -Name New-LosGovernanceProvenance -ErrorAction Stop

        $contractResult = & $contractCommand -ContractId $ContractId -ContractVersion $ContractVersion -RootPath $RootPath
        if (-not $contractResult.Success) {
            return New-LosBrokerDenyResult -Reason $contractResult.Reason
        }

        $schemaReference = Split-LosSchemaReference -SchemaReference $contractResult.Contract.outputSchema
        $schemaResult = Test-LosSchemaGate -SchemaId $schemaReference.SchemaId -SchemaVersion $schemaReference.SchemaVersion -RootPath $RootPath
        if (-not $schemaResult.Success) {
            return New-LosBrokerDenyResult -Reason $schemaResult.Reason
        }

        $attestationResult = Test-LosAttestationGate -ContractId $ContractId -ContractVersion $ContractVersion -ContractHash $contractResult.ContractHash -RootPath $RootPath
        if (-not $attestationResult.Success) {
            return New-LosBrokerDenyResult -Reason $attestationResult.Reason
        }

        $policyResult = & $policyCommand -Contract $contractResult.Contract -Runtime $Runtime -ExecutionContext $ExecutionContext -RequiredCapabilities $RequiredCapabilities
        if (-not $policyResult.Success) {
            return New-LosBrokerDenyResult -Reason $policyResult.Reason
        }

        $provenance = & $provenanceCommand `
            -ContractId $ContractId `
            -ContractVersion $ContractVersion `
            -ContractHash $contractResult.ContractHash `
            -SchemaHash $schemaResult.SchemaHash `
            -AttestationHash $attestationResult.AttestationHash `
            -PolicyHash $policyResult.PolicyHash `
            -Runtime $Runtime `
            -InputHash $InputHash `
            -OutputHash $OutputHash `
            -Decision "ALLOW" `
            -TimestampUtc $TimestampUtc

        [PSCustomObject][ordered]@{
            Success    = $true
            Decision   = "ALLOW"
            Contract   = $contractResult
            Schema     = $schemaResult
            Attestation = $attestationResult
            Policy     = $policyResult
            Provenance = $provenance
        }
    }
    catch {
        New-LosBrokerDenyResult -Reason "BrokerExecutionError"
    }
}

Export-ModuleMember -Function Invoke-LosExecutionBroker
