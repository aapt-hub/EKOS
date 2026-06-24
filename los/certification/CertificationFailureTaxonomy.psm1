Set-StrictMode -Version Latest

function Get-LOSCertificationFailure {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $FailureCategory,

        [Parameter()]
        [string] $Details = ""
    )

    $known = @(
        "GovernanceFailure",
        "ContractFailure",
        "SchemaFailure",
        "AttestationFailure",
        "ExecutionFailure",
        "ParityFailure",
        "DeterminismFailure",
        "LedgerFailure",
        "EvidenceFailure",
        "UnknownFailure"
    )

    if ($known -notcontains $FailureCategory) {
        $FailureCategory = "UnknownFailure"
    }

    return [PSCustomObject][ordered]@{
        Category = $FailureCategory
        Details  = $Details
    }
}

Export-ModuleMember -Function Get-LOSCertificationFailure

