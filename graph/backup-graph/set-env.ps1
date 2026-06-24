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

# ============================================================
# EKOS ENVIRONMENT SETUP
# Required for embedding engine
# ============================================================

Write-Host "Setting EKOS environment variables..." -ForegroundColor Cyan

# IMPORTANT: Replace with your real API key
$env:OPENAI_API_KEY = "PUT-YOUR-OPENAI-KEY-HERE"

Write-Host "OPENAI_API_KEY set for current session." -ForegroundColor Green