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