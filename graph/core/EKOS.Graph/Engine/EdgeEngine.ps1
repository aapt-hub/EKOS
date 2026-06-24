function Add-EdgeCore {
    param($From, $To, $Relation)

    $Global:EKOS_Graph.edges += @{
        from = $From
        to = $To
        relation = $Relation
    }

    return @{ success = $true }
}