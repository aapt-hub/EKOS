---
title: Runtime Authority Model
author: Abner Pauneto
project: EAi
repository_status: Private Development
license: Proprietary
copyright: Copyright (c) 2026 Abner Pauneto
last_updated: 2026-06-25
---

# Runtime Authority Model

Runtime authority is established by a deterministic chain retained for legacy EKOS-era reference:

```text
Contract
-> Schema
-> Attestation
-> Policy
-> Execution Broker
-> Runtime Execution
-> Certification
-> Trust Authority
-> Trust Monitoring
-> Trust Enforcement
-> Trust Recovery
-> Revalidation
-> Trust Authority Review
-> Active
```

Trust Recovery is LOS-TRUST-004. M2.11 is roadmap tracking only. Recovery approval authorizes revalidation; Active requires certification validation, attestation validation, policy validation, and trust authority review. Revoked subjects cannot directly recover.

AI-capable runtime paths are governed separately but still remain inside the same authority boundary. They must use `LOSi` for policy validation, `INDEXi` for context retrieval, `EKOSi` for reasoning, `PROVIDERi` for provider routing, and `CONTROLi` for workflow execution. Applications do not connect to providers directly.

Future authority stages add trust policy, dashboard visibility, and the Runtime Authority Kernel.

Author: Abner Pauneto
