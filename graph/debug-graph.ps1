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

# ============================================================
# EKOS GRAPH DEBUG VIEWER
# ============================================================

$nodesFile = "C:\Repos\EKOS\graph\nodes.json"
$edgesFile = "C:\Repos\EKOS\graph\edges.json"

Write-Host "`n=== NODES ===`n" -ForegroundColor Cyan
Get-Content $nodesFile | ConvertFrom-Json | Select-Object id, type, label, metadata

Write-Host "`n=== EDGES ===`n" -ForegroundColor Yellow
Get-Content $edgesFile | ConvertFrom-Json | Select-Object from, to, type, weight