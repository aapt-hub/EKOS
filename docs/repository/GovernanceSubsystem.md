---
title: Governance Subsystem
author: Abner Pauneto
project: EAi
repository_status: Private Development
license: Proprietary
copyright: Copyright (c) 2026 Abner Pauneto
last_updated: 2026-06-25
---

# Governance Subsystem

## Purpose

Governance enforces EAi policy and legacy LOS contract truth before runtime execution.

## Responsibilities

- Validate contracts.
- Validate schema references.
- Validate attestations.
- Evaluate runtime policy.
- Produce governance provenance.
- Emit compliance reports.
- Support EAi governance umbrella review.

## Dependencies

- `los/contracts/`
- `los/schemas/`
- `los/attestations/`
- `los/modules/`

## Current Maturity

M2.6 Governance Enforcement is implemented and covered by `los/tests/LOS.GovernanceEnforcement.Tests.ps1`.

## Future Roadmap

Governance feeds trust recovery, trust policy, trust dashboard, and Phase 3 Runtime Authority Kernel work.

Author: Abner Pauneto  
Project: EAi
Repository: EKOS  
License: Proprietary - All Rights Reserved
