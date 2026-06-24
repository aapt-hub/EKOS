# Runtime Subsystem

## Purpose

The runtime subsystem executes deterministic EKOS workflows while consuming LOS authority outputs.

## Responsibilities

- Preserve deterministic graph/runtime execution.
- Use LOS governance and trust decisions.
- Maintain separation between runtime behavior and truth-kernel authority.

## Dependencies

- LOS governance modules.
- LOS certification modules.
- LOS trust modules.
- Graph runtime and canonical serializer tools.

## Current Maturity

The LOS authority chain is implemented through M2.10. Broader Phase 3 Runtime Authority Kernel work remains planned.

## Future Roadmap

Runtime will integrate with recovery, trust policy, dashboard, and kernel controls as those milestones are implemented.

Author: Abner Pauneto  
Project: EKOS  
Repository: https://github.com/aapt-hub/EKOS  
License: MIT
