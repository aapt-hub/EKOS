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

# EKOS.Graph - Query Stability Test Suite (10 Tests)

Write-Host "`n==============================" -ForegroundColor Cyan
Write-Host " EKOS GRAPH - QUERY TEST SUITE " -ForegroundColor Cyan
Write-Host "==============================`n" -ForegroundColor Cyan

$tests = @(
    @{ Name="Test 1 - Analyze";   Input=@{ text="test-1"; type="analyze" } },
    @{ Name="Test 2 - Search";    Input=@{ text="find nodes"; type="search" } },
    @{ Name="Test 3 - Query";     Input=@{ text="select *"; type="query" } },
    @{ Name="Test 4 - Traverse";  Input=@{ text="walk graph"; type="traverse" } },
    @{ Name="Test 5 - Default";   Input=@{ text="no type provided" } },
    @{ Name="Test 6 - Uppercase"; Input=@{ text="case test"; type="ANALYZE" } },
    @{ Name="Test 7 - Whitespace";Input=@{ text="trim test"; type="  analyze  " } },
    @{ Name="Test 8 - Empty Text";Input=@{ text=""; type="analyze" } },
    @{ Name="Test 9 - Invalid";   Input=@{ text="bad type"; type="invalidType" } },
    @{ Name="Test 10 - Repeat";   Input=@{ text="repeat test"; type="analyze" } }
)

$results = @()
$passCount = 0
$failCount = 0

foreach ($t in $tests) {

    Write-Host "Running: $($t.Name)" -ForegroundColor Yellow

    try {
        $result = Invoke-EKOSQuery $t.Input

        $results += [PSCustomObject]@{
            Test   = $t.Name
            Status = "PASS"
            Output = ($result | Out-String).Trim()
        }

        Write-Host "   ✔ PASS" -ForegroundColor Green
        $passCount++

    } catch {
        $results += [PSCustomObject]@{
            Test   = $t.Name
            Status = "FAIL"
            Output = $_.Exception.Message
        }

        Write-Host "   ✖ FAIL - $($_.Exception.Message)" -ForegroundColor Red
        $failCount++
    }
}

Write-Host "`n==============================" -ForegroundColor Cyan
Write-Host " FINAL SUMMARY " -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan

Write-Host "Passed: $passCount" -ForegroundColor Green
Write-Host "Failed: $failCount" -ForegroundColor Red

Write-Host "`nDetailed Results:`n"

$results | Format-Table -AutoSize