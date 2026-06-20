function Add-Edge {
    param(
        [string]$From,
        [string]$To,
        [string]$Relation
    )

    Assert-EdgeIntegrity $From $To

    $result = Add-EdgeCore $From $To $Relation

    if ($result.success) {
        Save-Graph
    }

    return $result
}