---
title: EKOS Architecture
author: Abner Pauneto
project: EKOS
repository_status: Private Development
license: Proprietary
copyright: Copyright (c) 2026 Abner Pauneto
last_updated: 2026-06-24
---

# EKOS Architecture

Author: Abner Pauneto

## Purpose

This document defines the current EKOS / LOS / PETOS layered architecture through LOS-TRUST-004 Runtime Trust Recovery.

## Layer Model

```text
PETOS Application Layer
EKOS Runtime Execution Engine
LOS Operating System Truth Kernel
Linux / Windows Host Runtime Layer
```

## Current Runtime Chain

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

## Future Runtime Chain

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
-> Trust Policy
-> Trust Dashboard
-> Runtime Authority Kernel
```

## Implemented Architecture

### LOS: Operating System Truth Kernel

LOS owns contract truth, schema truth, attestation truth, governance enforcement, runtime certification, trust authority, trust monitoring, trust enforcement, and trust recovery.

Implemented LOS capabilities:

- Governance Enforcement: contract, schema, attestation, policy, broker, provenance, and compliance report checks.
- Runtime Certification: evidence generation, parity, ledger, report, failure taxonomy, and certification harness.
- Runtime Trust Authority: trust evidence, trust decisions, trust ledger, trust report, authority wrappers.
- Runtime Trust Monitoring: scoring, alerts, runtime events, health reports.
- Runtime Trust Enforcement: quarantine, deny, revoke, persisted enforcement state.
- Runtime Trust Recovery: evidence-based recovery request, approval, revalidation, trust authority review, append-only recovery ledger.

### LOS-TRUST-004: Runtime Trust Recovery

Capability ID: LOS-TRUST-004  
Roadmap Milestone: M2.11  
Name: Runtime Trust Recovery  
Domain: Trust  
Layer: LOS Trust Authority Layer

M2.11 is roadmap tracking only. LOS-TRUST-004 is the architectural capability. Recovery approval does not restore trust by itself; approval only authorizes revalidation. A subject can return to Active only after certification validation, attestation validation, policy validation, and trust authority review. Revoked subjects cannot directly recover.

### EKOS: Runtime Execution Engine

EKOS owns deterministic execution and graph runtime behavior. It consumes LOS contracts and trust decisions instead of redefining them.

### PETOS: Application Layer

PETOS owns application-facing workflows and UI/application integration. It uses EKOS execution and LOS truth without owning runtime authority.

### Host Runtime Layer

Linux and Windows provide host runtimes. Host-specific behavior stays outside LOS truth definitions.

## Design Constraints

- Deterministic execution behavior must be preserved.
- Trust decisions must fail closed.
- JSONL ledgers are append-only unless a module explicitly documents read-only state replacement.
- Public function names are stable unless a future compatibility layer is added.
- Documentation must not describe planned milestones as implemented.

## Roadmap Boundary

Implemented: M2.6 through M2.11.  
Planned: M2.12 through M2.13 and Phase 3 Runtime Authority Kernel.

Author: Abner Pauneto  
Project: EKOS  
Repository: EKOS  
License: Proprietary - All Rights Reserved
