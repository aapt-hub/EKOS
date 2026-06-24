---
title: Dependency Map
author: Abner Pauneto
project: EKOS
repository_status: Private Development
license: Proprietary
copyright: Copyright (c) 2026 Abner Pauneto
last_updated: 2026-06-24
---

# Dependency Map

## Purpose

Documents current runtime authority dependencies without changing implementation.

## Runtime Chain

```text
Contract -> Schema -> Attestation -> Policy -> Execution Broker -> Runtime Execution -> Certification -> Trust Authority -> Trust Monitoring -> Trust Enforcement
```

## Key Dependencies

- Governance depends on contracts, schemas, attestations, and policy.
- Certification depends on governance allow results, evidence generation, parity checks, canonical serialization, and ledger/report outputs.
- Trust Authority depends on governance and certification results.
- Trust Monitoring depends on trust ledger, certification ledger, trust scoring, and trust alerts.
- Trust Enforcement depends on trust status, trust score, alert severity, and enforcement state persistence.

## External Dependencies

Runtime modules use built-in PowerShell and .NET APIs. Tests use Pester.

Author: Abner Pauneto  
Project: EKOS  
Repository: EKOS  
License: Proprietary - All Rights Reserved
