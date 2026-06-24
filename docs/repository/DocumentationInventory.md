---
title: Documentation Inventory
author: Abner Pauneto
project: EKOS
repository_status: Private Development
license: Proprietary
copyright: Copyright (c) 2026 Abner Pauneto
last_updated: 2026-06-24
---

# Documentation Inventory

## Purpose

Repository-wide documentation synchronization inventory for the EKOS / LOS documentation and metadata sprint.

## Core Files Reviewed

| File path | Purpose | Phase referenced | Outdated references found | Synchronization action |
| --- | --- | --- | --- | --- |
| `README.md` | Repository overview | M2.6-M2.10 | Mixed EKOS.Graph and stale roadmap text | Replaced with current EKOS / LOS / PETOS overview |
| `architecture.md` | System architecture | M2.6-M2.10 | Placeholder architecture text | Replaced with current runtime authority model |
| `TODO.md` | Roadmap notes | M2.6-M2.13 | Old M2.7 scaffold wording | Replaced with implemented/planned status |
| `los/README.md` | LOS subsystem overview | M2.6-M2.10 | M2.6 and certification listed as future | Updated through M2.10 |
| `ekos/README.md` | EKOS subsystem overview | Current | Needed LOS/EKOS/PETOS boundary clarification | Updated |
| `wiki/README.md` | Wiki index | M2.6-M2.13 | Old limited wiki coverage | Rebuilt navigation |
| `wiki/Home.md` | Wiki home | M2.6-M2.10 | Old M2.7 wording | Updated |
| `wiki/Architecture.md` | Legacy architecture page | M2.6-M2.10 | Pointed to stale model | Converted to compatibility index |
| `wiki/Roadmap.md` | Legacy roadmap page | M2.6-M2.13 | M2.6 not started / Phase 3 blocked | Converted to current roadmap index |
| `wiki/Architecture-M2.7.md` | Legacy M2.7 architecture | M2.7 | Claimed M2.7 not implemented | Converted to compatibility page |
| `wiki/Roadmap-M2.7.md` | Legacy M2.7 roadmap | M2.7-M2.10 | Claimed M2.6 not started and Phase 3 blocked | Converted to compatibility page |
| `wiki/LOS-Governance.md` | LOS governance | M2.6-M2.10 | Phase 2.5-only view | Updated |
| `wiki/LOS-Authority-Boundary.md` | Authority boundary | M2.6-M2.10 | Planned-only enforcement text | Updated |

## Markdown Scope Reviewed

Reviewed repository markdown under:

- repository root
- `wiki/`
- `docs/repository/`
- `los/`
- `ekos/`

Historical pattern, ADR, runbook, and template documents were not rewritten because they represent domain examples or historical artifacts rather than current architecture authority pages.

## PowerShell Metadata Reviewed

Reviewed LOS runtime authority modules under:

- `los/modules/`
- `los/certification/`
- `los/registries/`
- `los/trust/`

Standardized headers were added to the current LOS trust modules. Detailed function help was added to the M2.10 public enforcement surface because it is the newest operational public API and most directly affected by this sprint.

## Documentation Gaps Discovered

- Legacy wiki pages described M2.6 as not started and Phase 3 certification as blocked.
- Top-level README mixed EKOS repository overview with old EKOS.Graph v3 material.
- LOS README stopped at governance foundation and did not include certification, trust authority, monitoring, or enforcement.
- Wiki hierarchy was flat and lacked separate governance, trust, runtime, EKOS, roadmap, and operations sections.
- Repository intelligence documents were missing.

## Quality Assessment

After synchronization, the primary documentation set now separates:

- Implemented: M2.6 through M2.10
- Planned: M2.11 through M2.13 and Phase 3 Runtime Authority Kernel
- Layer roles: LOS, EKOS, PETOS, host runtimes

Local markdown links in the synchronized docs/wiki set were validated with no broken local references.

Author: Abner Pauneto  
Project: EKOS  
Repository: EKOS  
License: Proprietary - All Rights Reserved
