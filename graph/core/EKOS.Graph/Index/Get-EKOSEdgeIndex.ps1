function Get-EKOSEdgeIndex {
    param(
        [string]$From,
        [string]$To
    )

    return $Global:EKOS_Index.EdgeByFrom[$From]
}