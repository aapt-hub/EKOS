function Assert-NodeName {
    param($Name)

    if ([string]::IsNullOrWhiteSpace($Name)) {
        throw "Node name cannot be empty"
    }
}

function Assert-EdgeIntegrity {
    param($From, $To)

    if ([string]::IsNullOrWhiteSpace($From) -or [string]::IsNullOrWhiteSpace($To)) {
        throw "Edge must have valid From and To"
    }
}