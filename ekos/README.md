# EKOS

EKOS is the Runtime Execution Engine.

## Purpose

EKOS executes deterministic runtime workflows and consumes LOS truth and trust decisions. It does not redefine LOS contracts, schemas, certification, or trust authority.

## Relationship To LOS

LOS is the Operating System Truth Kernel. EKOS uses LOS contracts, certification outputs, monitoring results, and enforcement decisions as authority inputs.

## Relationship To PETOS

PETOS is the Application Layer. PETOS uses EKOS execution services while remaining outside the LOS truth kernel.

## Current Scope

- Deterministic graph/runtime execution support.
- Audit orchestration under `ekos/audit/`.
- Integration boundary for future runtime authority work.

## Planned Scope

- Runtime Trust Recovery integration.
- Trust Policy Engine consumption.
- Runtime Trust Dashboard integration points.
- Phase 3 Runtime Authority Kernel integration.

Author: Abner Pauneto  
Project: EKOS  
Repository: https://github.com/aapt-hub/EKOS  
License: MIT
