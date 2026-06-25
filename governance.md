---
title: EAi Governance
author: Abner Pauneto
project: EAi
repository_status: Private Development
license: Proprietary
copyright: Copyright (c) 2026 Abner Pauneto
last_updated: 2026-06-25
---

# EAi Governance

EAi governance is the top-level umbrella for the frozen enterprise architecture.

## Governance Model

- EAi governs the enterprise architecture.
- Architecture is one governed domain.
- The frozen reference architecture is the single source of truth.
- The Constitution and EAi-S Enterprise Engineering Standard define the top-level principles and engineering rules.
- Monthly review covers normal architecture, business, and module changes.
- Weekly review is reserved for critical risk, security, provider, and runtime health items.
- No uncontrolled recursive automation is permitted.
- Controller-gated review lifecycle is required.
- Human approval is required before production changes.
- All recommendations must be explainable and auditable.

## Governance Responsibilities

- Business capability governance
- Business cycle review
- Pipeline leakage detection
- Retention risk detection
- Customer lifecycle tracking
- Revenue and process bottleneck detection
- Compliance validation
- Automation recommendations
- Owner notification workflows

## Safety And Control Requirements

- All provider integrations must go through `PROVIDERi`.
- All runtime decisions must be policy-checked by `LOSi`.
- `INDEXi` and `FACTORYi` are structure and planning services unless runtime is explicitly approved.
- All generated modules must pass controller tests.

## Controller-Gated Review Lifecycle

```text
Change Request
-> Governance Classification
-> Controller Review
-> Policy Check
-> Test Evidence
-> Approval
-> Dev/Test/Prod Promotion
-> Audit Capture
```

## Acceptance Criteria

- EAi governance is the top-level umbrella.
- The frozen reference architecture is the single source of truth.
- Monthly review handles normal changes.
- Weekly review handles critical-only items.
- Controller-gated review lifecycle is documented.
- Human approval is required before production changes.
- All provider integrations go through `PROVIDERi`.
- All runtime decisions are policy-checked by `LOSi`.
- All recommendations are explainable and auditable.

Author: Abner Pauneto
