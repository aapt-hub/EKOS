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

function Test-LOSCertificationParity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $LeftEvidence,

        [Parameter(Mandatory)]
        [object] $RightEvidence
    )

    $diffs = [System.Collections.Generic.List[object]]::new()

    $pairs = @(
        @{ Name = "InputHash"; Left = $LeftEvidence.InputHash; Right = $RightEvidence.InputHash },
        @{ Name = "OutputHash"; Left = $LeftEvidence.OutputHash; Right = $RightEvidence.OutputHash },
        @{ Name = "SchemaHash"; Left = $LeftEvidence.SchemaHash; Right = $RightEvidence.SchemaHash },
        @{ Name = "ExecutionPathHash"; Left = $LeftEvidence.ExecutionPathHash; Right = $RightEvidence.ExecutionPathHash },
        @{ Name = "DeterministicSignature"; Left = $LeftEvidence.DeterministicSignature; Right = $RightEvidence.DeterministicSignature }
    )

    foreach ($p in $pairs) {
        if ($p.Left -ne $p.Right) {
            $diffs.Add([PSCustomObject][ordered]@{
                Field = $p.Name
                Left  = $p.Left
                Right = $p.Right
            })
        }
    }

    if ($diffs.Count -eq 0) {
        return [PSCustomObject][ordered]@{
            ParityStatus = "Passed"
            Passed = $true
            Failed = $false
            Differences = @()
        }
    }

    return [PSCustomObject][ordered]@{
        ParityStatus = "Failed"
        Passed = $false
        Failed = $true
        Differences = $diffs
    }
}

Export-ModuleMember -Function Test-LOSCertificationParity

