---
title: EAi Methodology
author: Abner Pauneto
project: EAi
repository_status: Private Development
license: Proprietary
copyright: Copyright (c) 2026 Abner Pauneto
last_updated: 2026-06-25
---

# EAi Methodology

EAi methodology is documentation-first and structure-first.

## Operating Principles

- Start with governance, not implementation.
- Freeze the architecture before kernel development begins.
- Use the Constitution and EAi-S Enterprise Engineering Standard as the baseline.
- Prefer documentation, structure, and evidence before runtime code.
- Keep recursive automation disabled unless explicitly approved and bounded.
- Treat monthly review as the default cadence.
- Reserve weekly review for critical risk and security issues.

## Frozen Development Lifecycle

```text
Concept
-> Govern
-> Document
-> Structure
-> Validate
-> Approve
-> Promote
-> Observe
-> Review
```

## Planning Rules

- `EGK` owns graph infrastructure only.
- `ECK` owns capability governance only.
- `EDTi` owns enterprise state only.
- `ESF` exposes governed enterprise services only.
- `INDEXi` and `FACTORYi` are planning and structure services unless runtime is explicitly approved.
- `CONTROLi` owns workflow scheduling and promotion routing.
- `LOSi` owns policy checks for every decision that affects runtime.

## Promotion Rules

- Development -> Test -> Production promotion is strict.
- Human approval is required before production changes.
- All generated modules must pass controller tests.

## Acceptance Criteria

- Documentation-first and structure-first are the default where runtime is not yet approved.
- The frozen reference architecture is the source of truth.
- `INDEXi` and `FACTORYi` remain planning and structure services until runtime is explicitly approved.
- Development -> Test -> Production promotion is strict.
- Generated modules must pass controller tests.

Author: Abner Pauneto
