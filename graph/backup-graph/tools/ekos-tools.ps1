function search_files {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Path not found: $Path"
    }

    return Get-ChildItem -Path $Path -Recurse -File
}