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

# =========================
# EKOS CLEANUP SCRIPT v1 (FIXED)
# =========================

$root = "C:\repos\ekos"
$patternPath = Join-Path $root "patterns"
$metadataPath = Join-Path $root "metadata"

Write-Host "EKOS Cleanup Starting..." -ForegroundColor Cyan

# -------------------------
# Step 1: Collect patterns
# -------------------------
$files = Get-ChildItem -Path $patternPath -Filter "*.md"

Write-Host "`nScanning Patterns..."
Write-Host ("Total pattern files: " + $files.Count)

# -------------------------
# Step 2: Build ID map
# -------------------------
$idMap = @{}
$duplicates = @()

foreach ($file in $files) {

    if ($file.Name -match "PAT-(\d{4})") {
        $id = $matches[1]

        if ($idMap.ContainsKey($id)) {
            $idMap[$id] += $file
            $duplicates += $file
        }
        else {
            $idMap[$id] = @($file)
        }
    }
}

# -------------------------
# Step 3: Report duplicates
# -------------------------
Write-Host "`nDuplicate Analysis..." -ForegroundColor Yellow

foreach ($id in $idMap.Keys) {

    if ($idMap[$id].Count -gt 1) {
        Write-Host ("Duplicate PAT-" + $id + " detected:") -ForegroundColor Red

        $idMap[$id] | ForEach-Object {
            Write-Host (" - " + $_.Name)
        }
    }
}

# -------------------------
# Step 4: Canonical selection
# -------------------------
Write-Host "`nSelecting canonical files..." -ForegroundColor Cyan

$canonical = @()

foreach ($id in $idMap.Keys) {

    $group = $idMap[$id]

    $best = $group | Select-Object -First 1

    $canonical += $best

    Write-Host ("PAT-" + $id + " → " + $best.Name)
}

# -------------------------
# Step 5: Normalize filenames
# -------------------------
Write-Host "`nNormalizing filenames..." -ForegroundColor Cyan

foreach ($file in $canonical) {

    $newName = $file.Name.ToLower()
    $newName = $newName -replace "_", "-"
    $newName = $newName -replace " ", "-"

    if ($file.Name -ne $newName) {
        Rename-Item $file.FullName $newName -Force
        Write-Host ("Renamed: " + $file.Name + " → " + $newName)
    }
}

# -------------------------
# Step 6: Build index
# -------------------------
Write-Host "`nBuilding pattern index..." -ForegroundColor Cyan

$indexFile = Join-Path $metadataPath "pattern-index.md"

"# EKOS Pattern Index" | Out-File $indexFile -Encoding UTF8

foreach ($file in $canonical) {

    if ($file.Name -match "PAT-(\d{4})-(.+)\.md") {

        $id = $matches[1]
        $name = $matches[2]

        $entry = @"
## PAT-$id - $name
- File: patterns/$($file.Name)
"@

        Add-Content -Path $indexFile -Value $entry
    }
}

# -------------------------
# Step 7: Summary
# -------------------------
Write-Host "`nCleanup Complete" -ForegroundColor Green
Write-Host ("Total files scanned: " + $files.Count)
Write-Host ("Canonical patterns: " + $canonical.Count)
Write-Host ("Duplicates detected: " + $duplicates.Count)