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

# EKOS Sprint 1 - Relationship Engine
# Extracts explicit relationships using only the fixed Sprint 1 keywords.

function Get-EKOSRelationshipEdges {
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

    $relationships = @(
        "related to",
        "depends on",
        "uses",
        "implements",
        "see also"
    )

    $edges = @()
    $lines = $Text -split "\r?\n"

    foreach ($line in $lines) {
        foreach ($relationship in $relationships) {
            $keywordPattern = "(?i)\b" + [regex]::Escape($relationship) + "\b"
            $keywordMatch = [regex]::Match($line, $keywordPattern)

            if (-not $keywordMatch.Success) {
                continue
            }

            $textAfterKeyword = $line.Substring(
                $keywordMatch.Index + $keywordMatch.Length
            )

            # Prefer an explicit document ID after the relationship keyword.
            $documentMatch = [regex]::Match(
                $textAfterKeyword,
                "(?i)\b[A-Z][A-Z0-9]*-\d+\b"
            )

            if ($documentMatch.Success) {
                $target = $documentMatch.Value.ToUpperInvariant()

                if ($target -ne $DocumentId) {
                    $edges += [PSCustomObject]@{
                        from = $DocumentId
                        to   = $target
                        type = $relationship
                    }
                }

                continue
            }

            # If no document ID follows the keyword, look for a known entity.
            foreach ($entity in $entities) {
                $entityPattern = "(?i)(?<![a-z0-9])" +
                    [regex]::Escape($entity) +
                    "(?![a-z0-9])"

                if ($textAfterKeyword -match $entityPattern) {
                    $edges += [PSCustomObject]@{
                        from = $DocumentId
                        to   = $entity
                        type = $relationship
                    }
                }
            }
        }
    }

    return $edges
}
