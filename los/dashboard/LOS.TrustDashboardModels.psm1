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

Set-StrictMode -Version Latest

function ConvertTo-LOSTrustDashboardCanonicalObject {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object] $InputObject
    )

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [string] -or
        $InputObject -is [int] -or
        $InputObject -is [long] -or
        $InputObject -is [double] -or
        $InputObject -is [decimal] -or
        $InputObject -is [bool]) {
        return $InputObject
    }

    if ($InputObject -is [System.DateTime]) {
        return $InputObject.ToUniversalTime().ToString('o')
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $ordered = [ordered]@{}
        foreach ($key in @($InputObject.Keys | Sort-Object)) {
            $ordered[[string]$key] = ConvertTo-LOSTrustDashboardCanonicalObject -InputObject $InputObject[$key]
        }
        return [PSCustomObject]$ordered
    }

    if ($InputObject -is [System.Collections.IEnumerable] -and -not ($InputObject -is [string])) {
        $items = @()
        foreach ($item in $InputObject) {
            $items += ConvertTo-LOSTrustDashboardCanonicalObject -InputObject $item
        }
        return $items
    }

    $properties = @($InputObject.PSObject.Properties.Name | Sort-Object)
    if ($properties.Count -gt 0) {
        $ordered = [ordered]@{}
        foreach ($name in $properties) {
            $ordered[$name] = ConvertTo-LOSTrustDashboardCanonicalObject -InputObject $InputObject.$name
        }
        return [PSCustomObject]$ordered
    }

    return [string]$InputObject
}

function ConvertTo-LOSTrustDashboardStableJson {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object] $InputObject
    )

    $canonical = ConvertTo-LOSTrustDashboardCanonicalObject -InputObject $InputObject
    if ($null -eq $canonical) {
        return 'null'
    }

    return ($canonical | ConvertTo-Json -Depth 30 -Compress)
}

function Get-LOSTrustDashboardHash {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object] $InputObject
    )

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes((ConvertTo-LOSTrustDashboardStableJson -InputObject $InputObject))
        $hash = $sha.ComputeHash($bytes)
        return ([System.BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant()
    }
    finally {
        if ($sha -is [System.IDisposable]) {
            $sha.Dispose()
        }
    }
}

function New-LOSTrustDashboardOrderedObject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Values
    )

    $ordered = [ordered]@{}
    foreach ($key in @($Values.Keys | Sort-Object)) {
        $ordered[[string]$key] = $Values[$key]
    }

    return [PSCustomObject]$ordered
}

Export-ModuleMember -Function ConvertTo-LOSTrustDashboardStableJson, Get-LOSTrustDashboardHash, New-LOSTrustDashboardOrderedObject
