---
title: EAi Architecture
author: Abner Pauneto
project: EAi
repository_status: Private Development
license: Proprietary
copyright: Copyright (c) 2026 Abner Pauneto
last_updated: 2026-06-25
---

# EAi Architecture

Author: Abner Pauneto

## Purpose

This document defines the EAi 2.0 enterprise governance architecture.

Architecture is one governed domain under EAi. Governance remains the umbrella.

## Layer Model

```text
EAi Governance
-> EAi Architecture
-> EAi Knowledge
-> EAi Platform
-> Core Platform Components
-> Industry Solution Packs
```

## Core Platform Components

The core platform components are:

- `LOSi`
- `EKOSi`
- `CONTROLi`
- `INDEXi`
- `FACTORYi`
- `PROVIDERi`
- `CONSOLEi`
- `SDKi`
- `USEROBSERVEi`

## Governance Model

- `LOSi` owns policy, trust, identity, authorization, risk, and compliance checks.
- `EKOSi` owns AI, knowledge, recommendations, learning, and the competency graph.
- `CONTROLi` owns orchestration, workflows, scheduling, and routing.
- `INDEXi` owns catalog, discovery, search, metadata, and dependency lineage.
- `FACTORYi` owns module and repository generation.
- `PROVIDERi` owns all provider abstraction for AI, cloud, database, messaging, and identity integrations.
- `CONSOLEi` is the enterprise command center.
- `SDKi` is the developer entry point.
- `USEROBSERVEi` provides per-user observability and activity timeline tracking.

## Capability Graph

Capability Graph is a first-class architectural component.

It connects:

- business capabilities
- platform capabilities
- solution pack capabilities
- governance rules
- operational evidence
- owner notification workflows

## Promotion Model

- Development is controlled by documentation-first and structure-first work until runtime is approved.
- Development -> Test -> Production promotion requires controller approval.
- No uncontrolled recursive automation is permitted.
- All generated modules must pass controller tests before promotion.

## Solution Pack Model

Solution packs are optional, certified, composable, and deployable from `CONSOLEi` and `FACTORYi`.

`INDEXi` and `FACTORYi` remain structure and planning services unless runtime is explicitly approved.

## Legacy Architecture

The older EKOS / LOS / PETOS runtime architecture is preserved as compatibility material in the legacy wiki pages and subsystem folders.

## Design Constraints

- Governance is the top-level control surface.
- Monthly governance review handles normal changes.
- Weekly review is reserved for critical risk, security, and runtime issues.
- All provider integrations must go through `PROVIDERi`.
- All runtime decisions must be policy checked by `LOSi`.
- All recommendations must be explainable and auditable.
- Human approval is required before production changes.
- Dev/test/prod promotion must remain strict and explicit.

## Roadmap Boundary

Implemented: EAi 2.0 documentation and skeleton alignment.
Planned: runtime expansions only after controller approval.

Author: Abner Pauneto  
Project: EAi
Repository: EKOS  
License: Proprietary - All Rights Reserved
