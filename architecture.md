---
title: EAi Reference Architecture
author: Abner Pauneto
project: EAi
repository_status: Private Development
license: Proprietary
copyright: Copyright (c) 2026 Abner Pauneto
last_updated: 2026-06-25
---

# EAi Reference Architecture

EAi Reference Architecture is the frozen enterprise architecture for EAi.

EAi is an Enterprise Engineering Platform.
The architecture is the center.
No module may become the architectural center.

Everything is generated from the Reference Architecture.

## Immutable Foundation

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

## Kernel Hierarchy

```text
EAi Reference Architecture
        │
        ▼
Enterprise Graph Kernel (EGK)
        │
        ▼
Enterprise Capability Kernel (ECK)
        │
        ▼
Enterprise Digital Twin (EDTi)
        │
        ▼
Enterprise Service Fabric (ESF)
        │
        ▼
Platform Products
        │
        ▼
Business Platform
        │
        ▼
Industry Solutions
```

## Enterprise Graph Kernel

EGK owns graph infrastructure only.

### Responsibilities

- Graph storage
- Node management
- Relationship engine
- Traversal
- Graph indexes
- Transactions
- Versioning
- Snapshots
- Identity graph
- Dependency graph
- Capability graph
- Knowledge graph
- Event graph
- Serialization
- Integrity validation
- Optimization

### EGK never owns

- Business logic
- AI
- Policies
- Scheduling

## Enterprise Capability Kernel

ECK owns capability governance only.

### Responsibilities

- Capability registry
- Capability contracts
- Capability lifecycle
- Capability ownership
- Capability certification
- Capability versioning
- Capability dependencies
- Capability discovery
- Capability health
- Capability risk
- Capability policies
- Compliance mapping

### Every capability defines

- Owner
- Contract
- Lifecycle
- Dependencies
- Security
- Compliance
- Certification
- Observability

## Enterprise Digital Twin

EDTi owns enterprise state only.

### Models

- Organizations
- People
- Customers
- Applications
- Infrastructure
- Cloud
- Networks
- Containers
- Kubernetes
- Repositories
- Projects
- Modules
- Capabilities
- Security
- Risks
- Compliance
- Business Processes
- Documents
- Financial Pipelines
- Providers
- AI Models
- Observability
- Business Health
- Patch State
- Operational Readiness

## Enterprise Service Fabric

ESF exposes governed enterprise services.

### ESF does not own

- Capabilities
- Relationships
- State

### ESF exposes

- Capabilities
- Services
- Contracts
- Events
- Plugins
- Packages
- Connectors
- APIs

## Platform Products

Platform products consume architecture.

### Core platform products

- LOSi
- EKOSi
- CONTROLi
- PROVIDERi
- EDGEGATEWAYi
- FACTORYi
- INDEXi
- PACKAGINGi
- PACKAGEi
- PLUGINi
- EVENTi
- OBSERVEi
- USEROBSERVEi
- AUDITi
- BACKUPi
- SECURITYi
- CONSOLEi
- SDKi

### Governance-aligned roles

- LOSi: policy, trust, identity, authorization, risk, compliance
- EKOSi: reasoning, optimization, simulation, planning, recommendations, business intelligence, risk analysis, semantic search, automation intelligence
- CONTROLi: workflow, scheduling, automation, pipelines, event execution, orchestration, provider coordination
- PROVIDERi: cloud providers, AI providers, identity providers, storage, messaging, payments, CRM, ERP, PBX, communications, external APIs
- EDGEGATEWAYi: secure hybrid gateway, zero trust boundary, proxy, mutual TLS, offline sync, approved communications, air-gapped synchronization
- FACTORYi: repository generation, module generation, documentation generation, pipeline generation, packaging templates, testing templates, certification automation
- INDEXi: repository index, prompt index, documentation index, metadata catalog, capability index, architecture index
- PACKAGINGi: RPM, MSI, OCI images, Helm, Terraform modules, offline bundles, SBOM, artifact signing, certification metadata
- PACKAGEi: artifact registry, release registry, promotion, signing records
- PLUGINi: unified extension model
- EVENTi: enterprise event backbone
- OBSERVEi: telemetry, metrics, logs, tracing, health
- USEROBSERVEi: per-user timeline, behavior tracking, risk indicators
- AUDITi: immutable audit evidence
- BACKUPi: backup, restore, recovery validation
- SECURITYi: security scanning, hardening, compliance
- CONSOLEi: enterprise command center
- SDKi: CLI, APIs, developer tooling

## Business Platform

Business modules remain modular.

### Examples

- CRMi
- ACCOUNTINGi
- ERPi
- HRi
- PROJECTSi
- DOCUMENTSi
- PIPELINEi
- ITSMi
- MSPi
- HEALTHi
- LEGALi
- FINANCEi
- VOICEi
- COMPLIANCEi
- MARKETINGi
- NOCi
- SOCi

## Industry Solutions

Industry solutions are composed from business modules.

### Examples

- Healthcare
- Accounting
- MSP
- Government
- Defense
- Education
- Retail
- Construction
- Insurance
- Manufacturing

## Deployment Models

### Supported

- Single Server
- Small Business
- On Premises
- Private Cloud
- Public Cloud
- Hybrid
- Secure Hybrid
- Air Gapped
- Defense
- Disconnected Operations
- Customer Managed
- EAi Managed
- Secure Sandbox

### External communication rule

All external communications must traverse:

```text
LOSi
↓
EDGEGATEWAYi
↓
AUDITi
↓
PROVIDERi
↓
Approved Provider
```

## State Ownership

Explicit ownership is defined for:

- Configuration State
- Operational State
- Desired State
- Observed State
- Compliance State
- Digital Twin State
- Capability State
- Deployment State
- Audit State

No duplicated ownership is allowed.

## Contracts

Everything exposes contracts.

### Contract types

- Capability Contract
- Policy Contract
- Identity Contract
- Provider Contract
- Package Contract
- Plugin Contract
- Deployment Contract
- Audit Contract
- Event Contract
- Module Contract

## Metadata Standard

Every artifact must define:

- ID
- Name
- Owner
- Version
- Purpose
- Capability Class
- Dependencies
- Interfaces
- Contracts
- Security Classification
- Compliance Mapping
- Observability Hooks
- Lifecycle
- Certification
- Deployment Model
- External Communications
- SBOM Reference
- ADR References

## Technology Standards

Frozen standards:

- Primary Linux: Rocky Linux
- Backend: Go
- Security: Rust
- Windows: C#
- AI: Python
- Frontend: React and TypeScript
- Automation: PowerShell 7
- Database: PostgreSQL
- Cache: Redis / Valkey
- Object Storage: MinIO
- Messaging: NATS
- Streaming: Kafka only when justified
- Containers: OCI and Docker
- Orchestration: Kubernetes, K3s, RKE2
- Infrastructure: Terraform, OpenTofu
- Observability: OpenTelemetry, Prometheus, Grafana, Loki, Tempo, Alertmanager
- Identity: Keycloak, FreeIPA
- Security: Wazuh, Falco, OpenSCAP, Trivy, Grype, Syft, Cosign, Semgrep, SOPS, Vault-compatible

## Engineering Decision Records

Minimum ADR set:

- ADR-0001 Platform Root
- ADR-0002 Graph Kernel
- ADR-0003 Capability Kernel
- ADR-0004 Digital Twin
- ADR-0005 Enterprise Service Fabric
- ADR-0006 Rocky Linux
- ADR-0007 Go
- ADR-0008 Rust
- ADR-0009 Hybrid Deployment
- ADR-0010 Provider Abstraction

## Quality Gates

Every platform product must satisfy:

- Architecture
- Documentation
- Security
- Compliance
- Testing
- Contracts
- Packaging
- Signing
- SBOM
- Observability
- Performance
- Rollback
- Certification

## Repository Structure

Normalized repository structure:

- `README.md`
- `architecture.md`
- `governance.md`
- `methodology.md`
- `roadmap.md`
- `master-prompt.md`
- `docs/EAi-Constitution.md`
- `docs/EAi-S-Enterprise-Engineering-Standard.md`
- `docs/`
- `wiki/`
- `prompts/`
- `adr/`
- `contracts/`
- `schemas/`
- `registries/`
- `diagrams/`
- `tests/`
- `scripts/`
- `audits/`
- `releases/`

## Pre-M3 Constraints

Do not implement:

- Runtime services
- REST APIs
- Databases
- Kubernetes resources
- Workers
- Networking
- Daemon processes
- Long-running services

Focus only on:

- Architecture
- Documentation
- Governance
- Standards
- Contracts
- Schemas
- Registries
- Diagrams
- Navigation
- Repository structure

## Acceptance Criteria

- Architecture is internally consistent.
- No overlapping ownership exists.
- Reference Architecture is the single source of truth.
- EGK owns graph infrastructure.
- ECK owns capabilities.
- EDTi owns enterprise state.
- ESF exposes governed enterprise services.
- Platform products consume architecture.
- Business modules remain modular.
- Deployment models are documented.
- Technology standards are frozen.
- Repository structure is standardized.
- Cross references are valid.
- Architecture is implementation-ready.
- EAi is ready to begin M3 kernel development without architectural gaps.

Author: Abner Pauneto
