# Installation

The repository currently uses built-in PowerShell modules and Pester for tests.

Recommended validation:

```powershell
Import-Module Pester -MinimumVersion 5.0 -Force
Invoke-Pester .\los\tests\ -Output Minimal
```

Author: Abner Pauneto
