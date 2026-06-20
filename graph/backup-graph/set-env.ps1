# ============================================================
# EKOS ENVIRONMENT SETUP
# Required for embedding engine
# ============================================================

Write-Host "Setting EKOS environment variables..." -ForegroundColor Cyan

# IMPORTANT: Replace with your real API key
$env:OPENAI_API_KEY = "PUT-YOUR-OPENAI-KEY-HERE"

Write-Host "OPENAI_API_KEY set for current session." -ForegroundColor Green