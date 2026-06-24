---
title: Trust Enforcement
author: Abner Pauneto
project: EKOS
repository_status: Private Development
license: Proprietary
copyright: Copyright (c) 2026 Abner Pauneto
last_updated: 2026-06-24
---

# Trust Enforcement

Runtime Trust Enforcement is implemented in M2.10.

Primary module:

- `LOS.RuntimeTrustEnforcement.psm1`

Supported enforcement actions:

- Quarantine
- Deny
- Revoke

Enforcement state is persisted under `los/trust/data/runtime-trust-enforcement.json` in runtime roots.

Author: Abner Pauneto
