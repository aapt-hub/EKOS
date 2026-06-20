function Add-Node {
    param(
        [string]$Name,
        [string]$Type
    )

    Assert-NodeName $Name

    $result = Add-NodeCore $Name $Type

    if ($result.success) {
        Save-Graph
    }

    return $result
}