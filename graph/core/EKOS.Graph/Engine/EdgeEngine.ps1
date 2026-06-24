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

function Add-EdgeCore {
    param($From, $To, $Relation)

    $Global:EKOS_Graph.edges += @{
        from = $From
        to = $To
        relation = $Relation
    }

    return @{ success = $true }
}