# Certification Subsystem

## Purpose

Certification validates runtime execution evidence after governance allows execution.

## Responsibilities

- Generate certification evidence.
- Compute evidence hashes.
- Check parity.
- Write certification ledgers.
- Emit certification reports.
- Normalize failures.

## Dependencies

- Governance allow result.
- Canonical serializer.
- Certification modules under `los/certification/`.

## Current Maturity

M2.7 Runtime Certification is implemented and covered by `los/tests/Phase2.7.Tests.ps1`.

## Future Roadmap

Certification feeds trust authority, trust recovery, trust policy, and dashboard reporting.

Author: Abner Pauneto  
Project: EKOS  
Repository: https://github.com/aapt-hub/EKOS  
License: MIT
