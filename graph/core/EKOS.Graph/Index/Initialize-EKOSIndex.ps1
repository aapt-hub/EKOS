function Initialize-EKOSIndex {
    if (-not $Global:EKOS_Index) {
        $Global:EKOS_Index = @{
            NodeById = @{}
            EdgeByFrom = @{}
            EdgeByTo = @{}
        }
    }
}