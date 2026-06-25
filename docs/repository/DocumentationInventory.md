
---
title: Documentation Inventory
author: Abner Pauneto
project: EAi
repository_status: Private Development
license: Proprietary
copyright: Copyright (c) 2026 Abner Pauneto
last_updated: 2026-06-25
---

# Documentation Inventory

## Purpose

Repository-wide documentation synchronization inventory for the EAi 2.0 governance and compatibility alignment sprint.

## Core Files Reviewed

| File path | Purpose | Phase referenced | Outdated references found | Synchronization action |
| --- | --- | --- | --- | --- |
| `README.md` | Repository overview | EAi 2.0 | Mixed EKOS-era text | Replaced with EAi 2.0 enterprise governance overview |
| `architecture.md` | System architecture | EAi 2.0 | Legacy runtime-first framing | Replaced with governance-first architecture summary |
| `governance.md` | Governance overview | EAi 2.0 | Missing | Added governance umbrella, loops, and control rules |
| `methodology.md` | Methodology overview | EAi 2.0 | Missing | Added documentation-first and structure-first methodology |
| `roadmap.md` | Roadmap overview | EAi 2.0 | Missing | Added governance-driven roadmap framing |
| `master-prompt.md` | Master prompt | EAi 2.0 | Missing | Added aligned generation prompt |

| `ekos/README.md` | EKOS subsystem overview | Legacy | Needed EAi umbrella clarification | Updated |
| `wiki/README.md` | Wiki index | EAi 2.0 | Old limited wiki coverage | Rebuilt navigation |
| `wiki/Home.md` | Wiki home | EAi 2.0 | Old EKOS-era wording | Updated |
| `wiki/Architecture.md` | Legacy architecture page | EAi 2.0 | Pointed to stale model | Converted to compatibility index |
| `wiki/Roadmap.md` | Legacy roadmap page | Legacy | Retained for compatibility | Kept as historical roadmap index |
| `wiki/Architecture-M2.7.md` | Legacy M2.7 architecture | Legacy | Historical artifact | Retained as compatibility page |
| `wiki/Roadmap-M2.7.md` | Legacy M2.7 roadmap | Legacy | Historical artifact | Retained as compatibility page |
| `wiki/LOS-Governance.md` | LOS governance | Legacy | Phase 2.5-only view | Updated as legacy runtime authority material |
| `wiki/LOS-Authority-Boundary.md` | Authority boundary | Legacy | Planned-only enforcement text | Updated |

## Markdown Scope Reviewed

Reviewed repository markdown under:

- repository root
- `docs/`
- `wiki/`
- `platform/`
- `solutions/`
- `prompts/`
- `audits/`
- `architectures/`
- `stacks/`
- `standards/`
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
- Top-level README previously mixed EKOS repository overview with old EKOS.Graph v3 material.
- LOS README previously stopped at governance foundation and did not include certification, trust authority, monitoring, or enforcement.
- Wiki hierarchy previously lacked a governance-first EAi 2.0 entry point.
- EAi 2.0 root governance, methodology, roadmap, and master-prompt pages were missing.
- Platform, solution, prompt, and audit skeleton folders were missing.
- Repository intelligence documents still needed EAi 2.0 alignment language.

## Quality Assessment

After synchronization, the primary documentation set now separates:

- EAi 2.0 governance umbrella
- architecture as a governed domain
- legacy EKOS-era runtime authority pages
- platform, solution, prompt, and audit skeletons
- monthly review for normal work
- weekly review for critical-only items

Local markdown links in the synchronized docs/wiki set were validated with no broken local references.

Author: Abner Pauneto  
Project: EAi
Repository: EKOS  
License: Proprietary - All Rights Reserved
