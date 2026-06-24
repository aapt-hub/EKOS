function Get-EKOSNodeIndex {
    param([string]$Id)

    return $Global:EKOS_Index.NodeById[$Id]
}