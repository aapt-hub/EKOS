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

# EKOS Lock Manager v3.1 (Deadlock-safe minimal core)

$Global:EKOS_LockTable = @{
    Nodes = @{}
}

$Global:EKOS_WaitGraph = @{}

function Add-WaitEdge($from, $to) {

    if (-not $Global:EKOS_WaitGraph[$from]) {
        $Global:EKOS_WaitGraph[$from] = @()
    }

    $Global:EKOS_WaitGraph[$from] += $to
}

function Detect-Deadlock {

    $visited = @{}
    $stack = @{}

    function dfs($n) {

        if ($stack[$n]) { return $true }
        if ($visited[$n]) { return $false }

        $visited[$n] = $true
        $stack[$n] = $true

        foreach ($child in ($Global:EKOS_WaitGraph[$n] ?? @())) {
            if (dfs $child) { return $true }
        }

        $stack[$n] = $false
        return $false
    }

    foreach ($k in $Global:EKOS_WaitGraph.Keys) {
        if (dfs $k) { return $true }
    }

    return $false
}

function Acquire-EKOSLock {
    param($Id, $TxId)

    if (-not $Global:EKOS_LockTable.Nodes[$Id]) {

        $Global:EKOS_LockTable.Nodes[$Id] = @{
            Owner = $TxId
        }

        return
    }

    $owner = $Global:EKOS_LockTable.Nodes[$Id].Owner

    if ($owner -eq $TxId) { return }

    Add-WaitEdge $TxId $owner

    if (Detect-Deadlock) {
        throw "[EKOS.DEADLOCK] Cycle detected involving $TxId"
    }

    throw "[EKOS.LOCK] $Id held by $owner"
}

function Release-EKOSLock {
    param($Id, $TxId)

    if ($Global:EKOS_LockTable.Nodes[$Id].Owner -eq $TxId) {
        $Global:EKOS_LockTable.Nodes.Remove($Id)
    }

    $Global:EKOS_WaitGraph.Remove($TxId) | Out-Null
}