param(
    [Parameter(Mandatory=$true)]
    [string]$Id,

    [Parameter(Mandatory=$true)]
    [string]$From,

    [Parameter(Mandatory=$true)]
    [string]$To,

    [Parameter(Mandatory=$true)]
    [string]$Type,

    [double]$Weight = 1.0,

    [hashtable]$Metadata = @{}
)

$graphPath = "C:\Repos\EKOS\graph\edges.json"

if (!(Test-Path $graphPath)) {
    "[]" | Out-File $graphPath -Encoding UTF8
}

$edges = Get-Content $graphPath -Raw | ConvertFrom-Json

# prevent duplicates
if ($edges.id -contains $Id) {
    Write-Host "Edge already exists: $Id"
    exit 0
}

$edge = @{
    id = $Id
    from = $From
    to = $To
    type = $Type
    weight = $Weight
    metadata = $Metadata
    createdAt = (Get-Date).ToString("o")
}

$edges += $edge

$edges | ConvertTo-Json -Depth 10 | Out-File $graphPath -Encoding UTF8

Write-Host "Edge created: $From -> $To"