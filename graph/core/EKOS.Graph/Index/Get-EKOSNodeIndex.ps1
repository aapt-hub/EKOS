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

function Get-EKOSNodeIndex {
    param([string]$Id)

    return $Global:EKOS_Index.NodeById[$Id]
}