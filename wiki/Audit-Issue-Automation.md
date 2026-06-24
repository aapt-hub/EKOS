---
title: Audit Issue Automation
author: Abner Pauneto
project: EKOS
repository_status: Private Development
license: Proprietary
copyright: Copyright (c) 2026 Abner Pauneto
last_updated: 2026-06-24
---

# Audit Issue Automation

This document describes the audit failure GitHub issue automation scaffolding added to `ekos/audit`.

Key concepts:
- Deterministic issue titles and bodies
- Deterministic fingerprinting to suppress duplicates
- DryRun mode for offline/networkless validation
- Fail-closed behavior when `gh` is unavailable or RepositoryRoot is not in a git repo


