Set-StrictMode -Version Latest

function Invoke-EkosDriftEvaluatorV1 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]]$SnapshotA,

        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]]$SnapshotB
    )

    $SnapshotA = @($SnapshotA)
    $SnapshotB = @($SnapshotB)

    $status = 'Success'
    $errorResult = $null
    $added = @()
    $removed = @()
    $stable = @()
    $details = @()
    $driftScore = 0.0
    $isCritical = $false

    try {
        $logicalA = @{}
        $logicalB = @{}
        $sha256 = [System.Security.Cryptography.SHA256]::Create()

        try {
            foreach ($sourceNode in $SnapshotA) {
                $path = [string]$sourceNode.Path
                $name = [string]$sourceNode.Name
                $contentHash = [string]$sourceNode.ContentHash
                $identityInput = $path + $name + $contentHash
                $identityBytes = [System.Text.Encoding]::UTF8.GetBytes(
                    $identityInput
                )
                $identityKey = (
                    [System.BitConverter]::ToString(
                        $sha256.ComputeHash($identityBytes)
                    ) -replace '-', ''
                ).ToLowerInvariant()

                $node = [PSCustomObject][ordered]@{
                    Path        = $path
                    Name        = $name
                    ContentHash = $contentHash
                    IdentityKey = $identityKey
                }

                $logicalA[$path + "`0" + $name] = $node
            }

            foreach ($sourceNode in $SnapshotB) {
                $path = [string]$sourceNode.Path
                $name = [string]$sourceNode.Name
                $contentHash = [string]$sourceNode.ContentHash
                $identityInput = $path + $name + $contentHash
                $identityBytes = [System.Text.Encoding]::UTF8.GetBytes(
                    $identityInput
                )
                $identityKey = (
                    [System.BitConverter]::ToString(
                        $sha256.ComputeHash($identityBytes)
                    ) -replace '-', ''
                ).ToLowerInvariant()

                $node = [PSCustomObject][ordered]@{
                    Path        = $path
                    Name        = $name
                    ContentHash = $contentHash
                    IdentityKey = $identityKey
                }

                $logicalB[$path + "`0" + $name] = $node
            }
        }
        finally {
            $sha256.Dispose()
        }

        $added = @(
            foreach ($logicalKey in $logicalB.Keys) {
                if (-not $logicalA.ContainsKey($logicalKey)) {
                    $logicalB[$logicalKey]
                }
            }
        )

        $removed = @(
            foreach ($logicalKey in $logicalA.Keys) {
                if (-not $logicalB.ContainsKey($logicalKey)) {
                    $logicalA[$logicalKey]
                }
            }
        )

        $stable = @(
            foreach ($logicalKey in $logicalA.Keys) {
                if (
                    $logicalB.ContainsKey($logicalKey) -and
                    $logicalA[$logicalKey].ContentHash -ceq
                    $logicalB[$logicalKey].ContentHash
                ) {
                    $logicalB[$logicalKey]
                }
            }
        )

        $details = @(
            foreach ($logicalKey in $logicalA.Keys) {
                if (
                    $logicalB.ContainsKey($logicalKey) -and
                    $logicalA[$logicalKey].ContentHash -cne
                    $logicalB[$logicalKey].ContentHash
                ) {
                    [PSCustomObject][ordered]@{
                        Path           = $logicalB[$logicalKey].Path
                        Name           = $logicalB[$logicalKey].Name
                        ContentHash    = $logicalB[$logicalKey].ContentHash
                        IdentityKey    = $logicalB[$logicalKey].IdentityKey
                        OldContentHash = $logicalA[$logicalKey].ContentHash
                        NewContentHash = $logicalB[$logicalKey].ContentHash
                    }
                }
            }
        )

        $added = @($added | Sort-Object -Property IdentityKey)
        $removed = @($removed | Sort-Object -Property IdentityKey)
        $stable = @($stable | Sort-Object -Property IdentityKey)
        $details = @($details | Sort-Object -Property IdentityKey)

        $driftCount = (
            @($added).Count +
            @($removed).Count +
            @($details).Count
        )
        $driftScore = if (@($SnapshotA).Count -eq 0) {
            0.0
        }
        else {
            [double]$driftCount / [double]@($SnapshotA).Count
        }
        $isCritical = ($driftScore -gt 0.05)
    }
    catch {
        $status = 'Failure'
        $added = @()
        $removed = @()
        $stable = @()
        $details = @()
        $driftScore = 0.0
        $isCritical = $false
        $errorResult = [PSCustomObject][ordered]@{
            Message = $_.Exception.Message
            Type    = $_.Exception.GetType().FullName
        }
    }

    return [PSCustomObject][ordered]@{
        Status = $status
        Drift  = [PSCustomObject][ordered]@{
            Added       = @($added)
            Removed     = @($removed)
            Stable      = @($stable)
            Details     = @($details)
            DriftScore  = [double]$driftScore
            IsCritical  = [bool]$isCritical
        }
        Error  = $errorResult
    }
}

Set-Alias `
    -Name Invoke-EkosDriftEvaluatorV1_1 `
    -Value Invoke-EkosDriftEvaluatorV1 `
    -Scope Script

function Invoke-EkosGraphAudit {
    <#
    .SYNOPSIS
    Audits two EKOS graph snapshots for identity drift.

    .DESCRIPTION
    Invokes the external Invoke-EkosDriftEvaluatorV1_1 function and returns a
    stable audit result containing summary counts, raw drift details, and an
    overall cleanliness indicator. Evaluator failures are returned as
    structured details without terminating the calling pipeline.

    .PARAMETER SnapshotA
    The baseline EKOS graph snapshot.

    .PARAMETER SnapshotB
    The current EKOS graph snapshot.

    .OUTPUTS
    PSCustomObject

    .EXAMPLE
    Invoke-EkosGraphAudit -SnapshotA $baseline -SnapshotB $current

    .NOTES
    This command performs no filesystem, network, persistence, or graph
    traversal operations.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]]$SnapshotA,

        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]]$SnapshotB
    )

    $timestampUtc = [DateTime]::UtcNow.ToString(
        'o',
        [System.Globalization.CultureInfo]::InvariantCulture
    )
    $snapshotAInput = if ($null -eq $SnapshotA) { @() } else { @($SnapshotA) }
    $snapshotBInput = if ($null -eq $SnapshotB) { @() } else { @($SnapshotB) }

    Write-Verbose 'Starting EKOS graph drift audit.'

    try {
        $evaluator = Get-Command `
            -Name 'Invoke-EkosDriftEvaluatorV1_1' `
            -CommandType Alias, Function `
            -ErrorAction SilentlyContinue

        if ($null -eq $evaluator) {
            throw 'Invoke-EkosDriftEvaluatorV1_1 is not available.'
        }

        $evaluation = & $evaluator `
            -SnapshotA $snapshotAInput `
            -SnapshotB $snapshotBInput

        if ($evaluation.Status -cne 'Success') {
            throw $evaluation.Error.Message
        }

        $drift = [PSCustomObject][ordered]@{
            Added      = @($evaluation.Drift.Added)
            Removed    = @($evaluation.Drift.Removed)
            Stable     = @($evaluation.Drift.Stable)
            Changed    = @($evaluation.Drift.Details)
            DriftScore = [double]$evaluation.Drift.DriftScore
            IsCritical = [bool]$evaluation.Drift.IsCritical
        }

        $addedProperty = $drift.PSObject.Properties['Added']
        $removedProperty = $drift.PSObject.Properties['Removed']
        $stableProperty = $drift.PSObject.Properties['Stable']

        $addedCount = if ($null -eq $addedProperty) {
            0
        }
        else {
            @($addedProperty.Value).Count
        }
        $removedCount = if ($null -eq $removedProperty) {
            0
        }
        else {
            @($removedProperty.Value).Count
        }
        $movedCount = 0
        $stableCount = if ($null -eq $stableProperty) {
            0
        }
        else {
            @($stableProperty.Value).Count
        }

        Write-Verbose 'EKOS graph drift audit completed.'

        return [PSCustomObject][ordered]@{
            TimestampUtc = $timestampUtc
            Summary      = [PSCustomObject][ordered]@{
                Added   = $addedCount
                Removed = $removedCount
                Moved   = $movedCount
                Stable  = $stableCount
            }
            Details      = $drift
            IsClean      = (
                $addedCount -eq 0 -and
                $removedCount -eq 0 -and
                $movedCount -eq 0
            )
        }
    }
    catch {
        Write-Verbose 'EKOS graph drift audit could not be completed.'

        return [PSCustomObject][ordered]@{
            TimestampUtc = $timestampUtc
            Summary      = [PSCustomObject][ordered]@{
                Added   = 0
                Removed = 0
                Moved   = 0
                Stable  = 0
            }
            Details      = [PSCustomObject][ordered]@{
                ErrorType    = $_.Exception.GetType().FullName
                ErrorMessage = $_.Exception.Message
            }
            IsClean      = $false
        }
    }
}

Export-ModuleMember -Function Invoke-EkosGraphAudit
