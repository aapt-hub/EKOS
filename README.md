---
title: EAi 2.0
author: Abner Pauneto
project: EAi
repository_status: Private Development
license: Proprietary
copyright: Copyright (c) 2026 Abner Pauneto
last_updated: 2026-06-25
---

# EAi 2.0

EAi 2.0 is the Enterprise Governance Architecture for the platform.

It is the governing architecture and platform foundation for enterprise capabilities, business operations, AI, security, compliance, DevSecOps, observability, automation, and industry solutions.

## Core Domains

- EAi.Constitution
- EAi.Governance
- EAi.Methodology
- EAi.Architecture
- EAi.Knowledge
- EAi.Platform

## Core Platform Components

- LOSi - policy, trust, identity, authorization, risk, compliance
- EKOSi - AI, knowledge, recommendations, learning, competency graph
- CONTROLi - orchestration, workflows, scheduling, routing
- INDEXi - catalog, discovery, search, metadata, dependency lineage
- FACTORYi - module and repository generation, engineering automation
- PROVIDERi - provider abstraction for AI, cloud, database, messaging, identity
- CONSOLEi - enterprise command center
- SDKi - CLI, APIs, developer tooling
- USEROBSERVEi - per-user observability and activity timeline
- Industry Solution Packs

## Governance-First Model

Governance is the top-level umbrella.

Architecture is one governed domain under EAi.

Capability Graph is a first-class architectural component.

## Review Cadence

- Monthly review for normal architecture, business, and module changes.
- Weekly review only for critical items: vulnerabilities, patches, security advisories, provider changes, certificate expiration, secrets exposure, and runtime health.
- No uncontrolled recursive automation.
- Controller-gated review lifecycle.
- Human approval is required before production changes.
- Strict dev/test/prod promotion is required.

## Documentation And Structure

- Documentation-first and structure-first are used where runtime is not yet approved.
- All recommendations must be explainable and auditable.
- All provider integrations must go through `PROVIDERi`.
- All runtime decisions must be policy-checked by `LOSi`.

## Primary References

- [EAi 2.0 Enterprise Governance Architecture](docs/EAi-2.0-Enterprise-Governance-Architecture.md)
- [Governance](governance.md)
- [Architecture](architecture.md)
- [Methodology](methodology.md)
- [Roadmap](roadmap.md)
- [Master Prompt](master-prompt.md)

## Industry Solution Packs

Industry solution packs are optional, certified, composable, and deployable from `CONSOLEi` and `FACTORYi` without forcing the full platform to be generated for every customer.

Examples:

- Healthcarei
- Accountingi
- MSPi
- CRMi
- ERPi
- ITSMi
- Securityi
- Compliancei
- Financei
- Legali
- Educationi
- Governmenti
- Retaili
- Manufacturingi
- Logisticsi

## Legacy Notes

The older EKOS / LOS / PETOS documentation remains in the repository as legacy and compatibility material. The EAi 2.0 docs supersede the older framing where the two conflict.

Author: Abner Pauneto

## Repository Structure

- `platform/`: EAi platform components and skeletons.
- `solutions/`: Industry solution packs.
- `prompts/`: Master, governance, architecture, platform, module, and audit prompts.
- `audits/`: Architecture, governance, security, compliance, module, and release audit artifacts.
- `docs/`: EAi governance, methodology, architecture, and control references.
- `wiki/`: Legacy and compatibility docs organized by EAi domains.
- `los/`, `ekos/`, `petos/`, `graph/`: Existing subsystem history and implementation material.

## Validation Process

```powershell
Import-Module Pester -MinimumVersion 5.0 -Force
Invoke-Pester .\los\tests\ -Output Minimal
```

## Ownership

Author: Abner Pauneto  
Copyright: Copyright (c) 2026 Abner Pauneto  
License: Proprietary – All Rights Reserved  

## License

This repository is private proprietary software. Use, copying, modification, distribution, sublicensing, publication, reverse engineering, or commercial use requires express written permission from Abner Pauneto.
