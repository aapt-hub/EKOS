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

# Node.Store.ps1
# EKOS Graph Domain Layer - Node State

if (-not $Global:EKOS_Graph) {
    $Global:EKOS_Graph = @{
        nodes = @()
        edges = @()
    }
}