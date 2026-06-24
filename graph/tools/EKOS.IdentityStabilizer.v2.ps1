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

<#
.SYNOPSIS
EKOS Identity Stabilizer v2 - deterministic, read-only repository identity analysis.

.DESCRIPTION
Snapshots repository files, computes SHA256 identities, creates Identity Lock
Records (ILRs), maps legacy v0 node identities to v1.1 identities, detects
duplicate content identities, and reports drift. The module performs no file
mutation; all results are returned in memory.

.VERSION
2.0.0
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-EKOSSha256String {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Value
    )

    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
        $hash = $sha256.ComputeHash($bytes)
        return ([System.BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant()
    }
    finally {
        $sha256.Dispose()
    }
}

function Get-EkosContentKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Node
    )

    $contentHashProperty = $Node.PSObject.Properties['ContentHash']
    if ($null -eq $contentHashProperty) {
        $contentHashProperty = $Node.PSObject.Properties['contentSha256']
    }
    if ($null -eq $contentHashProperty) {
        $contentHashProperty = $Node.PSObject.Properties['hash']
    }

    if ($null -eq $contentHashProperty -or
        [string]::IsNullOrWhiteSpace([string]$contentHashProperty.Value)) {
        throw 'EKOS Invalid Node: missing ContentHash/contentSha256/hash'
    }

    # Content identity is independent of name and path. The content hash is
    # already a deterministic SHA256 value, so it is the canonical ContentKey.
    return ([string]$contentHashProperty.Value).ToLowerInvariant()
}

function Get-EkosContentPathMap {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Nodes
    )

    $map = @{}

    foreach ($node in $Nodes) {
        $contentKey = Get-EkosContentKey -Node $node

        $relativePathProperty = $node.PSObject.Properties['RelativePath']
        if ($null -eq $relativePathProperty) {
            $relativePathProperty = $node.PSObject.Properties['relativePath']
        }

        $pathProperty = $node.PSObject.Properties['Path']
        if ($null -eq $pathProperty) {
            $pathProperty = $node.PSObject.Properties['path']
        }

        $path = if ($null -ne $relativePathProperty -and
            -not [string]::IsNullOrWhiteSpace([string]$relativePathProperty.Value)) {
            [string]$relativePathProperty.Value
        }
        elseif ($null -ne $pathProperty -and
            -not [string]::IsNullOrWhiteSpace([string]$pathProperty.Value)) {
            [string]$pathProperty.Value
        }
        else {
            throw 'EKOS Invalid Node: missing RelativePath/Path'
        }
        $path = $path.Replace('\', '/').TrimStart('/')

        if (-not $map.ContainsKey($contentKey)) {
            $map[$contentKey] = [System.Collections.Generic.List[string]]::new()
        }

        $map[$contentKey].Add($path)
    }

    return $map
}

function Get-EkosActivePathMap {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$ContentPathMap
    )

    $activePathMap = @{}
    foreach ($contentKey in $ContentPathMap.Keys) {
        $activePath = $null

        foreach ($path in $ContentPathMap[$contentKey]) {
            $candidate = [string]$path
            if ($null -eq $activePath -or
                [System.StringComparer]::Ordinal.Compare($candidate, $activePath) -lt 0) {
                $activePath = $candidate
            }
        }

        if ($null -ne $activePath) {
            $activePathMap[$contentKey] = $activePath
        }
    }

    return $activePathMap
}

function Resolve-EkosActivePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ContentKey,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string[]]$Paths
    )

    $canonicalSet = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::Ordinal
    )

    foreach ($inputPath in $Paths) {
        if ($null -eq $inputPath) {
            throw 'EKOS Invalid Path: null paths are not allowed'
        }

        $normalizedInput = $inputPath.Normalize(
            [System.Text.NormalizationForm]::FormC
        ).Replace('\', '/')

        if ($normalizedInput.StartsWith('/', [System.StringComparison]::Ordinal) -or
            $normalizedInput.StartsWith('//', [System.StringComparison]::Ordinal) -or
            $normalizedInput -match '^[A-Za-z]:/') {
            throw "EKOS Invalid Path: absolute paths are not allowed: $inputPath"
        }

        $segments = [System.Collections.Generic.List[string]]::new()
        foreach ($segment in $normalizedInput.Split(
            [char[]]@('/'),
            [System.StringSplitOptions]::RemoveEmptyEntries
        )) {
            if ($segment -eq '.') {
                continue
            }

            if ($segment -eq '..') {
                if ($segments.Count -eq 0) {
                    throw "EKOS Invalid Path: path escapes repository root: $inputPath"
                }

                $segments.RemoveAt($segments.Count - 1)
                continue
            }

            $segments.Add($segment.Normalize(
                [System.Text.NormalizationForm]::FormC
            ))
        }

        $canonicalPath = [string]::Join('/', $segments)
        if ([string]::IsNullOrEmpty($canonicalPath)) {
            throw "EKOS Invalid Path: path resolves to repository root: $inputPath"
        }

        [void]$canonicalSet.Add($canonicalPath)
    }

    if ($canonicalSet.Count -eq 0) {
        throw 'EKOS Invalid Path Set: at least one path is required'
    }

    $canonicalPaths = [System.Collections.Generic.List[string]]::new(
        $canonicalSet.Count
    )
    foreach ($canonicalPath in $canonicalSet) {
        $canonicalPaths.Add($canonicalPath)
    }
    $canonicalPaths.Sort([System.StringComparer]::Ordinal)

    return [PSCustomObject][ordered]@{
        ContentKey     = $ContentKey
        ActivePath     = $canonicalPaths[0]
        CanonicalPaths = $canonicalPaths.ToArray()
        IsValid        = $true
        TimestampUtc   = [DateTime]::UtcNow.ToString('o')
    }
}

function Compare-EkosContentPathMaps {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$OldMap,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$NewMap
    )

    $moved = [System.Collections.Generic.List[object]]::new()
    $added = [System.Collections.Generic.List[object]]::new()
    $removed = [System.Collections.Generic.List[object]]::new()
    $stable = [System.Collections.Generic.List[object]]::new()

    $oldActivePaths = Get-EkosActivePathMap -ContentPathMap $OldMap
    $newActivePaths = Get-EkosActivePathMap -ContentPathMap $NewMap

    foreach ($contentKey in $oldActivePaths.Keys) {
        $oldActivePath = [string]$oldActivePaths[$contentKey]

        if ($newActivePaths.ContainsKey($contentKey)) {
            $newActivePath = [string]$newActivePaths[$contentKey]

            if ([System.StringComparer]::Ordinal.Equals($oldActivePath, $newActivePath)) {
                $stable.Add([PSCustomObject][ordered]@{
                    ContentKey = $contentKey
                    ActivePath = $newActivePath
                })
            }
            else {
                $moved.Add([PSCustomObject][ordered]@{
                    ContentKey = $contentKey
                    From       = $oldActivePath
                    To         = $newActivePath
                    ActivePath = $newActivePath
                })
            }
        }
        else {
            $removed.Add([PSCustomObject][ordered]@{
                ContentKey = $contentKey
                ActivePath = $oldActivePath
            })
        }
    }

    foreach ($contentKey in $newActivePaths.Keys) {
        if (-not $oldActivePaths.ContainsKey($contentKey)) {
            $newActivePath = [string]$newActivePaths[$contentKey]
            $added.Add([PSCustomObject][ordered]@{
                ContentKey = $contentKey
                ActivePath = $newActivePath
            })
        }
    }

    return [PSCustomObject][ordered]@{
        Moved         = $moved
        Added         = $added
        Removed       = $removed
        Stable        = $stable
        OldActivePath = $oldActivePaths
        NewActivePath = $newActivePaths
    }
}

function Get-EkosRelocations {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$OldNodes,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$NewNodes
    )

    $oldMap = Get-EkosContentPathMap -Nodes $OldNodes
    $newMap = Get-EkosContentPathMap -Nodes $NewNodes

    return Compare-EkosContentPathMaps -OldMap $oldMap -NewMap $newMap
}

function Get-EKOSCanonicalRoot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RootPath
    )

    $resolved = Resolve-Path -LiteralPath $RootPath -ErrorAction Stop
    if (-not (Test-Path -LiteralPath $resolved.Path -PathType Container)) {
        throw "Repository root is not a directory: $RootPath"
    }

    return [System.IO.Path]::GetFullPath($resolved.Path).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
}

function Get-EKOSCanonicalRelativePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RootPath,

        [Parameter(Mandatory)]
        [string]$FullPath
    )

    $rootWithSeparator = $RootPath.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    $rootUri = [System.Uri]::new($rootWithSeparator)
    $fileUri = [System.Uri]::new([System.IO.Path]::GetFullPath($FullPath))
    $relative = [System.Uri]::UnescapeDataString($rootUri.MakeRelativeUri($fileUri).ToString())
    return $relative.Replace('\', '/').TrimStart('/')
}

function Test-EKOSExcludedPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RelativePath,

        [string[]]$ExcludeDirectory = @('.git', 'bin', 'obj')
    )

    $segments = $RelativePath.Replace('\', '/').Split(
        [char[]]@('/'),
        [System.StringSplitOptions]::RemoveEmptyEntries
    )

    foreach ($segment in $segments) {
        foreach ($excluded in $ExcludeDirectory) {
            if ($segment.Equals($excluded, [System.StringComparison]::OrdinalIgnoreCase)) {
                return $true
            }
        }
    }

    return $false
}

function Get-EKOSRepositorySnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RootPath,

        [string[]]$ExcludeDirectory = @('.git', 'bin', 'obj')
    )

    $root = Get-EKOSCanonicalRoot -RootPath $RootPath
    $files = Get-ChildItem -LiteralPath $root -Recurse -Force -File -ErrorAction Stop
    $records = [System.Collections.Generic.List[object]]::new()

    foreach ($file in $files) {
        $relativePath = Get-EKOSCanonicalRelativePath -RootPath $root -FullPath $file.FullName
        if (Test-EKOSExcludedPath -RelativePath $relativePath -ExcludeDirectory $ExcludeDirectory) {
            continue
        }

        $contentSha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        $parentPath = [System.IO.Path]::GetDirectoryName($relativePath)
        if ($null -eq $parentPath) {
            $parentPath = ''
        }
        $parentPath = $parentPath.Replace('\', '/')

        # Required v2 identity contract:
        # Identity = SHA256(Path + Name + ContentHash)
        $identityMaterial = $parentPath + $file.Name + $contentSha256
        $identityFingerprint = Get-EKOSSha256String -Value $identityMaterial

        $records.Add([PSCustomObject][ordered]@{
            path                = $parentPath
            name                = $file.Name
            relativePath        = $relativePath
            extension           = $file.Extension
            size                = [long]$file.Length
            contentSha256       = $contentSha256
            identityFingerprint = $identityFingerprint
        })
    }

    $orderedRecords = @($records | Sort-Object -Property relativePath)
    $manifest = ($orderedRecords | ForEach-Object {
        "$($_.relativePath)`t$($_.size)`t$($_.contentSha256)`t$($_.identityFingerprint)"
    }) -join "`n"

    return [PSCustomObject][ordered]@{
        schemaVersion       = '1.1'
        algorithm           = 'SHA256'
        fileCount           = $orderedRecords.Count
        snapshotFingerprint = Get-EKOSSha256String -Value $manifest
        files               = $orderedRecords
    }
}

function New-EKOSIdentityLockRecords {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$Snapshot
    )

    process {
        $records = @($Snapshot.files | Sort-Object -Property relativePath | ForEach-Object {
            [PSCustomObject][ordered]@{
                schemaVersion       = '1.1'
                identityType        = 'repository-file'
                identityFingerprint = $_.identityFingerprint
                path                = $_.path
                name                = $_.name
                relativePath        = $_.relativePath
                contentSha256       = $_.contentSha256
                size                = [long]$_.size
                locked              = $true
            }
        })

        return $records
    }
}

function New-EKOSIdentityStore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$IdentityLockRecord
    )

    $identityStore = [ordered]@{}
    foreach ($ilr in @($IdentityLockRecord | Sort-Object -Property relativePath)) {
        if ([string]::IsNullOrWhiteSpace([string]$ilr.identityFingerprint)) {
            throw "No node without ILR: missing identity fingerprint for $($ilr.relativePath)"
        }
        if ($identityStore.Contains($ilr.identityFingerprint)) {
            throw "Duplicate identity fingerprint cannot create a unique ILR: $($ilr.identityFingerprint)"
        }

        $identityStore[$ilr.identityFingerprint] = $ilr
    }

    return $identityStore
}

function Get-EKOSLegacyIdentityIndex {
    [CmdletBinding()]
    param(
        [string]$LegacyIdentityPath
    )

    $index = @{}
    if ([string]::IsNullOrWhiteSpace($LegacyIdentityPath) -or
        -not (Test-Path -LiteralPath $LegacyIdentityPath -PathType Leaf)) {
        return $index
    }

    $legacyRecords = @(Get-Content -LiteralPath $LegacyIdentityPath -Raw -Encoding UTF8 |
        ConvertFrom-Json)

    foreach ($record in $legacyRecords) {
        if ($null -eq $record.path) {
            continue
        }

        $path = ([string]$record.path).Replace('\', '/').TrimStart('/')
        $legacyId = if ($null -ne $record.nodeId) {
            [string]$record.nodeId
        }
        elseif ($null -ne $record.id) {
            [string]$record.id
        }
        elseif ($null -ne $record.identity) {
            [string]$record.identity
        }
        else {
            $null
        }

        if (-not [string]::IsNullOrWhiteSpace($legacyId) -and -not $index.ContainsKey($path)) {
            $index[$path] = $legacyId.ToLowerInvariant()
        }
    }

    return $index
}

function New-EKOSMigrationMapping {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$IdentityLockRecord,

        [string]$LegacyIdentityPath
    )

    $legacyIndex = Get-EKOSLegacyIdentityIndex -LegacyIdentityPath $LegacyIdentityPath

    return @($IdentityLockRecord | Sort-Object -Property relativePath | ForEach-Object {
        $legacyIdentity = if ($legacyIndex.ContainsKey($_.relativePath)) {
            $legacyIndex[$_.relativePath]
        }
        else {
            $null
        }

        [PSCustomObject][ordered]@{
            path          = $_.relativePath
            fromVersion   = 'v0'
            fromIdentity  = $legacyIdentity
            toVersion     = 'v1.1'
            toIdentity    = $_.identityFingerprint
            mappingStatus = if ($null -eq $legacyIdentity) { 'new' } else { 'mapped' }
        }
    })
}

function Find-EKOSDuplicateIdentity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$IdentityLockRecord
    )

    $clusters = @($IdentityLockRecord |
        Group-Object -Property contentSha256 |
        Where-Object { $_.Count -gt 1 } |
        Sort-Object -Property Name)

    return @($clusters | ForEach-Object {
        $paths = @($_.Group.relativePath | Sort-Object)
        [PSCustomObject][ordered]@{
            contentIdentity = $_.Name
            count           = $paths.Count
            paths           = $paths
        }
    })
}

function Get-EKOSBaselineILR {
    [CmdletBinding()]
    param(
        [string]$BaselinePath
    )

    if ([string]::IsNullOrWhiteSpace($BaselinePath) -or
        -not (Test-Path -LiteralPath $BaselinePath -PathType Leaf)) {
        return @()
    }

    $document = Get-Content -LiteralPath $BaselinePath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -ne $document.identityLockRecords) {
        return @($document.identityLockRecords)
    }

    return @($document)
}

function Get-EKOSIdentityDriftReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$IdentityLockRecord,

        [string]$BaselinePath
    )

    $baseline = @(Get-EKOSBaselineILR -BaselinePath $BaselinePath)
    if ($baseline.Count -eq 0) {
        return [PSCustomObject][ordered]@{
            baselineProvided = $false
            hasDrift          = $false
            activePaths       = @{}
            moved             = @()
            added             = @()
            removed           = @()
            stable            = @()
        }
    }

    $comparison = Get-EkosRelocations `
        -OldNodes $baseline `
        -NewNodes $IdentityLockRecord

    return [PSCustomObject][ordered]@{
        baselineProvided = $true
        hasDrift          = (($comparison.Moved.Count + $comparison.Added.Count +
                $comparison.Removed.Count) -gt 0)
        activePaths       = $comparison.NewActivePath
        moved             = $comparison.Moved
        added             = $comparison.Added
        removed           = $comparison.Removed
        stable            = $comparison.Stable
    }
}

function ConvertTo-EKOSDeterministicJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$InputObject,

        [ValidateRange(2, 100)]
        [int]$Depth = 20
    )

    process {
        return ($InputObject | ConvertTo-Json -Depth $Depth)
    }
}

function Invoke-EKOSIdentityStabilizerV2 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RootPath
    )

    $root = Get-EKOSCanonicalRoot -RootPath $RootPath
    $legacyIdentityPath = Join-Path -Path $root -ChildPath 'ekos.identity.graph.json'
    if (-not (Test-Path -LiteralPath $legacyIdentityPath -PathType Leaf)) {
        $legacyIdentityPath = $null
    }

    $snapshot = Get-EKOSRepositorySnapshot -RootPath $root
    $ilr = @(New-EKOSIdentityLockRecords -Snapshot $snapshot)
    $identityStore = New-EKOSIdentityStore -IdentityLockRecord $ilr

    foreach ($node in $snapshot.files) {
        if (-not $identityStore.Contains($node.identityFingerprint)) {
            throw "No node without ILR: $($node.relativePath)"
        }
    }

    $migration = @(New-EKOSMigrationMapping `
        -IdentityLockRecord $ilr `
        -LegacyIdentityPath $legacyIdentityPath)
    $duplicates = @(Find-EKOSDuplicateIdentity -IdentityLockRecord $ilr)

    $legacyNodes = @()
    if ($null -ne $legacyIdentityPath) {
        $legacyNodes = @(
            Get-Content -LiteralPath $legacyIdentityPath -Raw -Encoding UTF8 |
                ConvertFrom-Json
        )
    }
    $relocations = Get-EkosRelocations `
        -OldNodes $legacyNodes `
        -NewNodes $snapshot.files

    $migrationPlan = [PSCustomObject][ordered]@{
            fromVersion = 'v0'
            toVersion   = 'v1.1'
            mappings    = $migration
    }

    $driftReport = [PSCustomObject][ordered]@{
        hasDrift           = (($relocations.Moved.Count + $relocations.Added.Count +
                $relocations.Removed.Count) -gt 0)
        activePaths        = $relocations.NewActivePath
        moved              = $relocations.Moved
        added              = $relocations.Added
        removed            = $relocations.Removed
        stable             = $relocations.Stable
        duplicateIdentities = $duplicates
    }

    return [PSCustomObject][ordered]@{
        Snapshot      = $snapshot
        IdentityStore = $identityStore
        MigrationPlan = $migrationPlan
        DriftReport   = $driftReport
    }
}
