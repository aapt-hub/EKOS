---
title: EAi
author: Abner Pauneto
project: EAi
repository_status: Private Development
license: Proprietary
copyright: Copyright (c) 2026 Abner Pauneto
last_updated: 2026-06-25
---

# EAi

EAi is the Enterprise Engineering Platform.

The architecture is the center.
No module may become the architectural center.

Everything is generated from the Reference Architecture.

## Frozen Foundation

```text
EAi
├── EAi.Constitution
├── EAi-S Enterprise Engineering Standard
├── EAi.ReferenceArchitecture
├── EAi.Governance
├── EAi.Methodology
├── EAi.EngineeringToolchain
├── EAi.Knowledge
├── Enterprise Graph Kernel (EGK)
├── Enterprise Capability Kernel (ECK)
├── Enterprise Digital Twin (EDTi)
├── Enterprise Service Fabric (ESF)
├── Platform Products
├── Business Platform
├── Industry Solutions
└── Deployment Models
```

## Reference Architecture

The official reference architecture is frozen in [architecture.md](architecture.md) and mirrored in [docs/EAi-Reference-Architecture.md](docs/EAi-Reference-Architecture.md).

## Design Rules

- Capability driven
- Graph driven
- Policy driven
- Contract driven
- Metadata driven
- Event driven
- Governed
- Observable
- Certifiable

## Current Freeze Scope

- Documentation
- Governance
- Standards
- Contracts
- Schemas
- Registries
- Diagrams
- Repository structure

## Legacy Material

Legacy EKOS-era material remains in the repository as compatibility history and must not override the frozen reference architecture.

## Primary References

- [Architecture](architecture.md)
- [EAi Constitution](docs/EAi-Constitution.md)
- [EAi-S Enterprise Engineering Standard](docs/EAi-S-Enterprise-Engineering-Standard.md)
- [Governance](governance.md)
- [Methodology](methodology.md)
- [Roadmap](roadmap.md)
- [EAi Reference Architecture](docs/EAi-Reference-Architecture.md)
- [EAi Governance Architecture](docs/EAi-2.0-Enterprise-Governance-Architecture.md)
- [Master Prompt](master-prompt.md)

## Repository Structure

- `docs/`: Canonical EAi architecture, governance, methodology, and standards.
- `wiki/`: Legacy and compatibility documentation.
- `platform/`: Platform product skeletons.
- `solutions/`: Industry solution skeletons.
- `adr/`: Architecture decision records.
- `contracts/`: Contract definitions and placeholders.
- `schemas/`: Schema definitions and placeholders.
- `registries/`: Registry placeholders.
- `diagrams/`: Reference diagrams.
- `tests/`: Architecture validation placeholders.
- `scripts/`: PowerShell-first operational scripts.
- `audits/`: Audit and evidence placeholders.
- `releases/`: Release and promotion placeholders.

## Acceptance Criteria

- EAi is defined as an Enterprise Engineering Platform.
- EAi.ReferenceArchitecture is the single source of truth.
- EGK owns graph infrastructure only.
- ECK owns capability governance only.
- EDTi owns enterprise state only.
- ESF exposes governed enterprise services only.
- Platform products consume architecture.
- Business modules remain modular.
- Deployment models are documented.
- Technology standards are frozen.
- Repository structure is standardized.
- Cross references are valid.
- The architecture is implementation-ready for M3 kernel development.

Author: Abner Pauneto
