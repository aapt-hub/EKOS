$root = (Get-Location).Path

$input = Join-Path $root "ekos.identity.graph.json"

$raw = Get-Content $input | ConvertFrom-Json

function Get-NodeType($path, $ext) {

    $p = $path.ToLower()

    if ($p -match "\\bin\\|\\obj\\|\.dll$|\.pdb$|\.cache$") {
        return "build"
    }

    if ($ext -in @(".cs", ".fs", ".ps1")) {
        return "source"
    }

    if ($ext -in @(".json", ".slnx", ".config", ".yml", ".yaml")) {
        return "config"
    }

    if ($ext -in @(".md")) {
        return "architecture"
    }

    if ($p -match "\\graph\\") {
        return "graph"
    }

    if ($p -match "\\templates\\|\\patterns\\|\\standards\\") {
        return "architecture"
    }

    if ($p -match "\\runbooks\\") {
        return "execution"
    }

    return "unknown"
}

$classified = $raw | ForEach-Object {

    $type = Get-NodeType $_.path $_.extension

    if ($type -eq "build") { return $null }

    [PSCustomObject]@{
        nodeId = $_.nodeId
        path = $_.path
        name = $_.name
        extension = $_.extension
        type = $type
        hash = $_.hash
    }

} | Where-Object { $_ -ne $null }

$out = Join-Path $root "ekos.system.graph.json"

$classified | ConvertTo-Json -Depth 6 | Set-Content $out -Encoding UTF8

Write-Host "STRICT SYSTEM NODES: $($classified.Count)"
Write-Host "OUTPUT: $out"