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

Set-StrictMode -Version Latest

. (Join-Path (Split-Path $PSScriptRoot -Parent) 'utils\ConvertTo-CanonicalJson.ps1')

function Assert-EkosDeterminism {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    $outputs = [System.Collections.Generic.List[string]]::new()
    for ($run = 0; $run -lt 3; $run++) {
        $result = & $ScriptBlock
        $outputs.Add((ConvertTo-CanonicalJson -InputObject $result))
    }

    if ($outputs[0] -cne $outputs[1] -or
        $outputs[0] -cne $outputs[2]) {
        $diff = [PSCustomObject][ordered]@{
            IsDeterministic = $false
            Runs            = $outputs.ToArray()
        }
        Write-Output $diff
        throw 'EKOS determinism assertion failed.'
    }

    return [PSCustomObject][ordered]@{
        IsDeterministic = $true
        CanonicalJson   = $outputs[0]
    }
}
