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

function Initialize-EKOSIndex {
    if (-not $Global:EKOS_Index) {
        $Global:EKOS_Index = @{
            NodeById = @{}
            EdgeByFrom = @{}
            EdgeByTo = @{}
        }
    }
}