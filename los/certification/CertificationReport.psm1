Set-StrictMode -Version Latest

function New-LOSCertificationReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Evidence,

        [Parameter(Mandatory)]
        [object] $GovernanceStatus,

        [Parameter(Mandatory)]
        [object] $ParityResult,

        [Parameter(Mandatory)]
        [string] $EvidenceHash,

        [Parameter(Mandatory)]
        [string] $CertificationStatus,

        [Parameter(Mandatory)]
        [string] $TimestampUtc,

        [Parameter(Mandatory)]
        [object] $Failure
    )

    $report = [PSCustomObject][ordered]@{
        CertificationId      = $Evidence.CertificationId
        ExecutionId          = $Evidence.ExecutionId
        CertificationStatus  = $CertificationStatus
        GovernanceStatus     = $GovernanceStatus
        ParityStatus         = $ParityResult.ParityStatus
        EvidenceHash        = $EvidenceHash
        Runtime              = $Evidence.Runtime
        TimestampUtc        = $TimestampUtc
        FailureCategory     = $Failure.Category
    }

    $json = $report | ConvertTo-Json -Depth 10
    return $json
}

Export-ModuleMember -Function New-LOSCertificationReport

