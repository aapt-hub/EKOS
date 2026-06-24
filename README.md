# EKOS

EKOS is the Runtime Execution Engine in the EKOS repository. It works with LOS, PETOS, and host runtimes to provide deterministic execution, governance, certification, and runtime trust controls.

## System Layers

- LOS = Operating System Truth Kernel
- EKOS = Runtime Execution Engine
- PETOS = Application Layer
- Linux / Windows = Host Runtime Layer

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
```

## Implementation Status

Implemented:

- M2.6 Governance Enforcement
- M2.7 Runtime Certification
- M2.8 Runtime Trust Authority
- M2.9 Runtime Trust Monitoring
- M2.10 Runtime Trust Enforcement

Planned:

- M2.11 Runtime Trust Recovery
- M2.12 Trust Policy Engine
- M2.13 Runtime Trust Dashboard
- Phase 3 Runtime Authority Kernel

## Repository Map

- `los/`: Operating System Truth Kernel modules, contracts, schemas, certification, trust, tests, and reports.
- `ekos/`: EKOS-owned runtime and audit orchestration modules.
- `petos/`: Application-layer scaffolding and application-facing framework boundary.
- `graph/`: Deterministic graph runtime and canonical serialization tools.
- `wiki/`: Maintained architecture, governance, trust, runtime, and roadmap documentation.
- `docs/repository/`: Repository intelligence documents for module inventory, dependency mapping, and subsystem status.

## Validation

LOS tests are the primary validation surface for M2.6 through M2.10:

```powershell
Import-Module Pester -MinimumVersion 5.0 -Force
Invoke-Pester .\los\tests\ -Output Minimal
```

## Author

Abner Pauneto

Creator and Lead Architect of:

- LOS Runtime Authority Architecture
- EKOS Runtime Engine
- PETOS Application Framework

Author: Abner Pauneto  
Project: EKOS  
Repository: https://github.com/aapt-hub/EKOS  
License: MIT
