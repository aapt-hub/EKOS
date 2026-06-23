# Roadmap

Repository implementation is the source of truth. Documentation must not describe planned milestones as implemented unless matching source artifacts exist.

## Current Status

- Phase 2.5 Governance Foundation: COMPLETE
- Documentation Refresh: IN PROGRESS
- Phase 2.6 Governance Enforcement: NOT STARTED
- Phase 3 Runtime Certification: BLOCKED

## Phase 2.5 Governance Foundation (COMPLETE)

- Evidence in the repository:
  - `los/contracts/EKOS.Execute/1.0.0/contract.json`
  - `los/schemas/execution-result/1.0.0/schema.json`
  - `los/attestations/contract/EKOS.Execute/1.0.0/attestation.json`
  - `los/registries/LOS.ContractRegistry.psm1`
  - `los/registries/LOS.SchemaRegistry.psm1`
  - `los/registries/LOS.ArtifactLoader.psm1`
  - `los/registries/LOS.AttestationRegistry.psm1`
  - `los/reports/Phase-2.5-Governance-Report.md`

## Planned

- M2.7 layer model and documentation/state updates are not implemented as a milestone.
- Audit issue automation documentation references existing files under `ekos/audit/`, but this does not make M2.7 complete.

## Not Implemented Yet

- Phase 2.6 Governance Enforcement: NOT STARTED
- `los/registries/LOS.GovernanceValidator.psm1`
- Runtime enforcement gate
- Contract-required execution
- Execution certification pipeline

## Blocked

- Phase 3 Runtime Certification: BLOCKED until Phase 2.6 Governance Enforcement is complete.
- Remaining PETOS / EKOS / compute-fabric / training-fabric milestones listed in the M3.x roadmap



