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

EAi methodology is documentation-first and structure-first where runtime is not yet approved.

## Operating Principles

- Start with governance, not implementation.
- Prefer documentation, structure, and evidence before runtime code.
- Use controller-gated review for promotion.
- Keep recursive automation disabled unless explicitly approved and bounded.
- Treat monthly review as the default cadence.
- Reserve weekly review for critical risk and security issues.

## Lifecycle

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

- `INDEXi` is used for catalog, discovery, metadata, and dependency lineage.
- `FACTORYi` is used for repository and module generation.
- Both remain planning and structure services unless runtime is explicitly approved.
- `CONTROLi` owns workflow scheduling and promotion routing.
- `LOSi` owns policy checks for every decision that affects runtime.

## Review Cadence

- Monthly review covers ordinary architectural, business, and solution-pack work.
- Weekly review covers critical security, provider, certificate, and runtime items only.

## Promotion Rules

- Development -> Test -> Production promotion is strict.
- Human approval is required before production changes.
- All generated modules must pass controller tests.

## Related References

- [EAi Governance](governance.md)
- [EAi Architecture](architecture.md)
- [Module Lifecycle](docs/Module-Lifecycle.md)

## Acceptance Criteria

- Documentation-first and structure-first are the default where runtime is not yet approved.
- `INDEXi` and `FACTORYi` remain planning and structure services until runtime is explicitly approved.
- Development -> Test -> Production promotion is strict.
- Generated modules must pass controller tests.

Author: Abner Pauneto
