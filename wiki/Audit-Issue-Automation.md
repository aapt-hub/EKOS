# Audit Issue Automation

This document describes the audit failure GitHub issue automation scaffolding added to `ekos/audit`.

Key concepts:
- Deterministic issue titles and bodies
- Deterministic fingerprinting to suppress duplicates
- DryRun mode for offline/networkless validation
- Fail-closed behavior when `gh` is unavailable or RepositoryRoot is not in a git repo


