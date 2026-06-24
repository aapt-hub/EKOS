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

function Invoke-EKOSIntegrityCheck {
    param(
        [hashtable]$Graph,
        [string]$Mode = "PreCommit"
    )

    Test-EKOSSchema -Graph $Graph
    Test-EKOSDuplicateEdge -Graph $Graph
    Test-EKOSCycle -Graph $Graph

    return @{
        Status = "PASSED"
        Mode   = $Mode
    }
}