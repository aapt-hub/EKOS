# Testing

LOS validation is performed with Pester:

```powershell
Import-Module Pester -MinimumVersion 5.0 -Force
Invoke-Pester .\los\tests\ -Output Minimal
```

Current LOS tests cover M2.6 through M2.10.

Author: Abner Pauneto
