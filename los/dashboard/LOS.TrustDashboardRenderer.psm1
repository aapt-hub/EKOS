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

function ConvertTo-LOSTrustDashboardText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Dashboard
    )

    $summary = @()
    $summary += "LOS Runtime Trust Dashboard"
    $summary += "ReportHash: {0}" -f $Dashboard.ReportHash
    $summary += "RuntimeHealth: {0}" -f $Dashboard.RuntimeHealth.RuntimeHealth
    $summary += "TrustScore: {0}" -f $Dashboard.TrustScore
    $summary += "PolicyRegistryStatus: {0}" -f $Dashboard.PolicyRegistryStatus
    $summary += "LoadedPolicyCount: {0}" -f $Dashboard.LoadedPolicyCount
    $summary += "ActivePolicyCount: {0}" -f $Dashboard.ActivePolicyCount
    $summary += "RuntimeSubjects: total={0}; active={1}; quarantined={2}; revoked={3}; recovering={4}" -f `
        $Dashboard.RuntimeSubjects.Total,
        $Dashboard.RuntimeSubjects.Active,
        $Dashboard.RuntimeSubjects.Quarantined,
        $Dashboard.RuntimeSubjects.Revoked,
        $Dashboard.RuntimeSubjects.Recovering
    $summary += "EnforcementSummary: total={0}; quarantine={1}; deny={2}; revoke={3}" -f `
        $Dashboard.EnforcementSummary.Total,
        $Dashboard.EnforcementSummary.Quarantine,
        $Dashboard.EnforcementSummary.Deny,
        $Dashboard.EnforcementSummary.Revoke
    $summary += "RecoverySummary: total={0}; active={1}; recovering={2}; approved={3}; denied={4}" -f `
        $Dashboard.RecoverySummary.Total,
        $Dashboard.RecoverySummary.Active,
        $Dashboard.RecoverySummary.Recovering,
        $Dashboard.RecoverySummary.Approved,
        $Dashboard.RecoverySummary.Denied
    $summary += "AlertSummary: total={0}; active={1}; resolved={2}; critical={3}; warning={4}; info={5}" -f `
        $Dashboard.AlertSummary.Total,
        $Dashboard.AlertSummary.Active,
        $Dashboard.AlertSummary.Resolved,
        $Dashboard.AlertSummary.Critical,
        $Dashboard.AlertSummary.Warning,
        $Dashboard.AlertSummary.Info

    return ($summary -join [Environment]::NewLine)
}

function ConvertTo-LOSTrustDashboardJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Dashboard
    )

    return ConvertTo-LOSTrustDashboardStableJson -InputObject $Dashboard
}

Export-ModuleMember -Function ConvertTo-LOSTrustDashboardText, ConvertTo-LOSTrustDashboardJson
