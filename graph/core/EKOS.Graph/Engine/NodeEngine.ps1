function Add-NodeCore {
    param($Name, $Type)

    if (-not $Global:EKOS_Graph.nodes.ContainsKey($Name)) {
        $Global:EKOS_Graph.nodes[$Name] = @{
            name = $Name
            type = $Type
        }

        return @{ success = $true; node = $Name }
    }

    return @{ success = $false; reason = "exists" }
}