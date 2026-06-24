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

function Get-EKOSEdgeIndex {
    param(
        [string]$From,
        [string]$To
    )

    return $Global:EKOS_Index.EdgeByFrom[$From]
}