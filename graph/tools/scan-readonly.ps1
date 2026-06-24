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

$root = Get-Location

$files = Get-ChildItem -Recurse -File | Where-Object {
    $_.FullName -notmatch "\\bin\\" -and
    $_.FullName -notmatch "\\obj\\"
}

$graph = foreach ($f in $files) {

    $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue

    $hash = if ($content) {
        (Get-FileHash $f.FullName -Algorithm SHA256).Hash
    } else {
        "EMPTY"
    }

    [PSCustomObject]@{
        path = $f.FullName.Replace($root, "")
        name = $f.Name
        extension = $f.Extension
        size = $f.Length
        hash = $hash
    }
}

$graph | ConvertTo-Json -Depth 4 | Out-File ".\ekos.graph.snapshot.json"