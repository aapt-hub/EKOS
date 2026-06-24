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

# EKOS.Graph v3.3 Vector Engine
# Parallel traversal + BFS/DFS acceleration layer

# ----------------------------
# VECTOR EXECUTION CONTEXT
# ----------------------------

$Global:EKOS_Vector = @{
    MaxThreads = 4
}

# ----------------------------
# PARALLEL BFS
# ----------------------------

function Invoke-ParallelBFS {
    param(
        [string]$StartNode,
        [scriptblock]$Visit
    )

    $visited = @{}
    $queue = New-Object System.Collections.Queue

    $queue.Enqueue($StartNode)
    $visited[$StartNode] = $true

    while ($queue.Count -gt 0) {

        $batch = @()

        # Build batch for parallel execution
        while ($queue.Count -gt 0 -and $batch.Count -lt $Global:EKOS_Vector.MaxThreads) {
            $batch += $queue.Dequeue()
        }

        # Process batch in parallel
        $batch | ForEach-Object -Parallel {

            param($node, $Visit)

            & $Visit $node

        } -ArgumentList $Visit

        foreach ($node in $batch) {

            $neighbors = Get-OutNeighbors -NodeId $node

            foreach ($n in ($neighbors ?? @())) {

                if (-not $visited[$n]) {
                    $visited[$n] = $true
                    $queue.Enqueue($n)
                }
            }
        }
    }
}

# ----------------------------
# PARALLEL DFS
# ----------------------------

function Invoke-ParallelDFS {
    param(
        [string]$StartNode,
        [scriptblock]$Visit
    )

    $visited = @{}
    $stack = New-Object System.Collections.Stack

    $stack.Push($StartNode)

    while ($stack.Count -gt 0) {

        $batch = @()

        while ($stack.Count -gt 0 -and $batch.Count -lt $Global:EKOS_Vector.MaxThreads) {
            $batch += $stack.Pop()
        }

        $batch | ForEach-Object -Parallel {

            param($node, $Visit)

            & $Visit $node

        } -ArgumentList $Visit

        foreach ($node in $batch) {

            $neighbors = Get-OutNeighbors -NodeId $node

            foreach ($n in ($neighbors ?? @())) {

                if (-not $visited[$n]) {
                    $visited[$n] = $true
                    $stack.Push($n)
                }
            }
        }
    }
}

# ----------------------------
# BULK NODE PROCESSING
# ----------------------------

function Invoke-VectorMapNodes {
    param(
        [string]$Type,
        [scriptblock]$Operation
    )

    $nodes = Get-NodesByType $Type

    $nodes | ForEach-Object -Parallel {

        param($nodeId, $Operation)

        $node = Get-NodeById $nodeId

        & $Operation $node

    } -ArgumentList $Operation
}