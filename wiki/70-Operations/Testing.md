---
title: Testing
author: Abner Pauneto
project: EAi
repository_status: Private Development
license: Proprietary
copyright: Copyright (c) 2026 Abner Pauneto
last_updated: 2026-06-24
---

# Testing

LOS validation is performed with Pester:

```powershell
Import-Module Pester -MinimumVersion 5.0 -Force
Invoke-Pester .\los\tests\ -Output Minimal
```

Current LOS tests cover M2.6 through M2.10.

Author: Abner Pauneto
