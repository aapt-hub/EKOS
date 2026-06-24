param(
    [Parameter(Mandatory=$true)]
    [string]$Id,

    [Parameter(Mandatory=$true)]
    [string]$Type,

    [Parameter(Mandatory=$true)]
    [string]$Label,

    [hashtable]$Metadata = @{}
)

$graphPath = "C:\Repos\EKOS\graph\nodes.json"

if (!(Test-Path $graphPath)) {
    "[]" | Out-File $graphPath -Encoding UTF8
}

$nodes = Get-Content $graphPath -Raw | ConvertFrom-Json

# prevent duplicates
if ($nodes.id -contains $Id) {
    Write-Host "Node already exists: $Id"
    exit 0
}

$node = @{
    id = $Id
    type = $Type
    label = $Label
    metadata = $Metadata
    createdAt = (Get-Date).ToString("o")
    updatedAt = (Get-Date).ToString("o")
}

$nodes += $node

$nodes | ConvertTo-Json -Depth 10 | Out-File $graphPath -Encoding UTF8

Write-Host "Node created: $Id"