function Invoke-EKOSQueryOptimizer {

    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Query
    )

    if (-not $Query.ContainsKey("Type") -or [string]::IsNullOrWhiteSpace($Query.Type)) {
        $Query.Type = "analyze"
    }

    if (-not $Query.ContainsKey("Text")) {
        $Query.Text = ""
    }

    $Query.Type = $Query.Type.ToLower().Trim()

    $ValidTypes = @("analyze","search","query","traverse")

    if ($Query.Type -notin $ValidTypes) {
        throw "[EKOS.OPT] Unknown query type: $($Query.Type)"
    }

    switch ($Query.Type) {
        "analyze"  { return @{ Type="AnalyzeResult";  Input=$Query.Text } }
        "search"   { return @{ Type="SearchResult";   Input=$Query.Text } }
        "query"    { return @{ Type="QueryResult";    Input=$Query.Text } }
        "traverse" { return @{ Type="TraverseResult"; Input=$Query.Text } }
    }
}

Export-ModuleMember -Function Invoke-EKOSQueryOptimizer