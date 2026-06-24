Set-StrictMode -Version Latest

function Get-LOSTrustAlertsPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RootPath
    )

    $monitoringDir = Join-Path $RootPath "los\monitoring"
    if (-not (Test-Path -LiteralPath $monitoringDir)) {
        New-Item -ItemType Directory -Path $monitoringDir | Out-Null
    }

    return Join-Path $monitoringDir "trust-alerts.jsonl"
}

function New-LOSTrustAlert {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RootPath,

        [string] $AlertId = "",

        [Parameter(Mandatory)]
        [string] $TrustId,

        [Parameter(Mandatory)]
        [ValidateSet("Info", "Warning", "Critical")]
        [string] $Severity,

        [Parameter(Mandatory)]
        [string] $Type,

        [Parameter(Mandatory)]
        [string] $Source,

        [Parameter(Mandatory)]
        [string] $Message,

        [AllowNull()]
        [object] $Evidence,

        [string] $TimestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    )

    if ([string]::IsNullOrWhiteSpace($AlertId)) {
        $AlertId = [guid]::NewGuid().ToString("N")
    }

    $alert = [PSCustomObject][ordered]@{
        AlertId      = $AlertId
        TimestampUtc = $TimestampUtc
        TrustId      = $TrustId
        Severity     = $Severity
        Type         = $Type
        Source       = $Source
        Message      = $Message
        Evidence     = $Evidence
        Status       = "Active"
    }

    Add-Content -LiteralPath (Get-LOSTrustAlertsPath -RootPath $RootPath) -Value ($alert | ConvertTo-Json -Depth 20 -Compress)
    return $alert
}

function Get-LOSTrustAlerts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RootPath,

        [string] $TrustId = "",

        [ValidateSet("", "Active", "Resolved")]
        [string] $Status = ""
    )

    $path = Get-LOSTrustAlertsPath -RootPath $RootPath
    if (-not (Test-Path -LiteralPath $path)) {
        return @()
    }

    $alerts = @()
    foreach ($line in @(Get-Content -LiteralPath $path)) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        $alert = $line | ConvertFrom-Json
        if (-not [string]::IsNullOrWhiteSpace($TrustId) -and $alert.TrustId -ne $TrustId) {
            continue
        }
        if (-not [string]::IsNullOrWhiteSpace($Status) -and $alert.Status -ne $Status) {
            continue
        }

        $alerts += $alert
    }

    return $alerts
}

function Resolve-LOSTrustAlert {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RootPath,

        [Parameter(Mandatory)]
        [string] $AlertId,

        [string] $Message = "Resolved",

        [string] $TimestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    )

    $existing = $null
    foreach ($alert in @(Get-LOSTrustAlerts -RootPath $RootPath)) {
        if ($alert.AlertId -eq $AlertId) {
            $existing = $alert
        }
    }

    if ($null -eq $existing) {
        return [PSCustomObject][ordered]@{
            Success = $false
            Status  = "NotFound"
            AlertId = $AlertId
        }
    }

    $resolution = [PSCustomObject][ordered]@{
        AlertId      = $AlertId
        TimestampUtc = $TimestampUtc
        TrustId      = $existing.TrustId
        Severity     = $existing.Severity
        Type         = "Resolution"
        Source       = "Resolve-LOSTrustAlert"
        Message      = $Message
        Evidence     = [PSCustomObject][ordered]@{
            ResolvedAlertType = $existing.Type
        }
        Status       = "Resolved"
    }

    Add-Content -LiteralPath (Get-LOSTrustAlertsPath -RootPath $RootPath) -Value ($resolution | ConvertTo-Json -Depth 20 -Compress)
    return $resolution
}

Export-ModuleMember -Function New-LOSTrustAlert, Get-LOSTrustAlerts, Resolve-LOSTrustAlert
