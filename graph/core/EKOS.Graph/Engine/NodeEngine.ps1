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

function Add-NodeCore {
    param($Name, $Type)

    if (-not $Global:EKOS_Graph.nodes.ContainsKey($Name)) {
        $Global:EKOS_Graph.nodes[$Name] = @{
            name = $Name
            type = $Type
        }

        return @{ success = $true; node = $Name }
    }

    return @{ success = $false; reason = "exists" }
}