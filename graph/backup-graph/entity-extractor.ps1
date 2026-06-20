# EKOS Sprint 1 - Entity Extractor
# Extracts mentions of the fixed Sprint 1 entity list from document text.

function Get-EKOSEntityEdges {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DocumentId,

        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    $entities = @(
        "aws",
        "terraform",
        "kubernetes",
        "docker",
        "github",
        "powershell",
        "vmware",
        "windows server",
        "active directory"
    )

    $edges = @()

    foreach ($entity in $entities) {
        $pattern = "(?i)(?<![a-z0-9])" + [regex]::Escape($entity) + "(?![a-z0-9])"

        if ($Text -match $pattern) {
            $edges += [PSCustomObject]@{
                from = $DocumentId
                to   = $entity
                type = "mentions"
            }
        }
    }

    return $edges
}
