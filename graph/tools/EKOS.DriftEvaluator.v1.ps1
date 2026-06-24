function Invoke-EkosDriftEvaluatorV1 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$SnapshotA,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$SnapshotB
    )

    function ConvertTo-EkosDriftNode {
        param(
            [Parameter(Mandatory)]
            [object]$Node
        )

        foreach ($propertyName in @('Path', 'Name', 'ContentHash')) {
            $property = $Node.PSObject.Properties[$propertyName]
            if ($null -eq $property -or $null -eq $property.Value) {
                throw "EKOS Invalid Node: missing $propertyName"
            }
        }

        $path = [string]$Node.Path
        $name = [string]$Node.Name
        $contentHash = [string]$Node.ContentHash
        $identityInput = $path + $name + $contentHash
        $sha256 = [System.Security.Cryptography.SHA256]::Create()

        try {
            $identityBytes = [System.Text.Encoding]::UTF8.GetBytes($identityInput)
            $identityHash = $sha256.ComputeHash($identityBytes)
        }
        finally {
            $sha256.Dispose()
        }

        $identityKey = (
            $identityHash |
                ForEach-Object { $_.ToString('x2') }
        ) -join ''

        return [PSCustomObject][ordered]@{
            Path        = $path
            Name        = $name
            ContentHash = $contentHash
            IdentityKey = $identityKey
        }
    }

    function Get-EkosOrdinallySortedNodes {
        param(
            [Parameter(Mandatory)]
            [AllowEmptyCollection()]
            [object[]]$Nodes
        )

        $sortable = [System.Collections.Generic.List[object]]::new()
        foreach ($node in $Nodes) {
            $sortable.Add($node)
        }

        $sortable.Sort(
            [System.Comparison[object]]{
                param($left, $right)

                $comparison = [System.StringComparer]::Ordinal.Compare(
                    [string]$left.Path,
                    [string]$right.Path
                )
                if ($comparison -ne 0) {
                    return $comparison
                }

                $comparison = [System.StringComparer]::Ordinal.Compare(
                    [string]$left.Name,
                    [string]$right.Name
                )
                if ($comparison -ne 0) {
                    return $comparison
                }

                return [System.StringComparer]::Ordinal.Compare(
                    [string]$left.ContentHash,
                    [string]$right.ContentHash
                )
            }
        )

        return $sortable.ToArray()
    }

    $logicalA = @{}
    $logicalB = @{}

    foreach ($sourceNode in $SnapshotA) {
        $node = ConvertTo-EkosDriftNode -Node $sourceNode
        $logicalKey = $node.Path + "`0" + $node.Name
        if ($logicalA.ContainsKey($logicalKey)) {
            throw "EKOS Invalid SnapshotA: duplicate Path+Name: $($node.Path) $($node.Name)"
        }
        $logicalA[$logicalKey] = $node
    }

    foreach ($sourceNode in $SnapshotB) {
        $node = ConvertTo-EkosDriftNode -Node $sourceNode
        $logicalKey = $node.Path + "`0" + $node.Name
        if ($logicalB.ContainsKey($logicalKey)) {
            throw "EKOS Invalid SnapshotB: duplicate Path+Name: $($node.Path) $($node.Name)"
        }
        $logicalB[$logicalKey] = $node
    }

    $added = [System.Collections.Generic.List[object]]::new()
    $removed = [System.Collections.Generic.List[object]]::new()
    $stable = [System.Collections.Generic.List[object]]::new()
    $moved = [System.Collections.Generic.List[object]]::new()
    $changed = [System.Collections.Generic.List[object]]::new()

    foreach ($logicalKey in $logicalB.Keys) {
        $newNode = $logicalB[$logicalKey]

        if ($logicalA.ContainsKey($logicalKey)) {
            $oldNode = $logicalA[$logicalKey]
            if ([System.StringComparer]::Ordinal.Equals(
                [string]$oldNode.IdentityKey,
                [string]$newNode.IdentityKey
            )) {
                $stable.Add($newNode)
            }
            else {
                $changed.Add([PSCustomObject][ordered]@{
                    Path           = $newNode.Path
                    Name           = $newNode.Name
                    OldContentHash = $oldNode.ContentHash
                    NewContentHash = $newNode.ContentHash
                    OldIdentityKey = $oldNode.IdentityKey
                    NewIdentityKey = $newNode.IdentityKey
                })
            }
        }
        else {
            $added.Add($newNode)
        }
    }

    foreach ($logicalKey in $logicalA.Keys) {
        if (-not $logicalB.ContainsKey($logicalKey)) {
            $removed.Add($logicalA[$logicalKey])
        }
    }

    $addedOutput = Get-EkosOrdinallySortedNodes -Nodes $added.ToArray()
    $removedOutput = Get-EkosOrdinallySortedNodes -Nodes $removed.ToArray()
    $stableOutput = Get-EkosOrdinallySortedNodes -Nodes $stable.ToArray()
    $movedOutput = @($moved)
    $changed.Sort(
        [System.Comparison[object]]{
            param($left, $right)

            foreach ($propertyName in @(
                'Path',
                'Name',
                'OldContentHash',
                'NewContentHash'
            )) {
                $comparison = [System.StringComparer]::Ordinal.Compare(
                    [string]$left.$propertyName,
                    [string]$right.$propertyName
                )
                if ($comparison -ne 0) {
                    return $comparison
                }
            }

            return 0
        }
    )
    $changedOutput = $changed.ToArray()

    $driftCount = $addedOutput.Count + $removedOutput.Count + $changedOutput.Count
    $driftScore = if ($SnapshotA.Count -eq 0) {
        if ($driftCount -eq 0) { 0.0 } else { 1.0 }
    }
    else {
        [double]$driftCount / [double]$SnapshotA.Count
    }

    return [PSCustomObject][ordered]@{
        Added      = $addedOutput
        Removed    = $removedOutput
        Stable     = $stableOutput
        Moved      = $movedOutput
        Changed    = $changedOutput
        DriftScore = $driftScore
        IsCritical = ($driftScore -gt 0.05)
    }
}
