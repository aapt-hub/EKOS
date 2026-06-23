# Roadmap — Planned M2.7 Documentation

Repository implementation is the source of truth. Documentation must not describe planned milestones as implemented unless matching source artifacts exist.

## Current Status

- Phase 2.5 Governance Foundation: COMPLETE
- Documentation Refresh: IN PROGRESS
- Phase 2.6 Governance Enforcement: NOT STARTED
- Phase 3 Runtime Certification: BLOCKED

## Current Implemented State

- Phase 2.5 Governance Foundation: COMPLETE
- Evidence:
  - `los/contracts/EKOS.Execute/1.0.0/contract.json`
  - `los/schemas/execution-result/1.0.0/schema.json`
  - `los/attestations/contract/EKOS.Execute/1.0.0/attestation.json`
  - `los/registries/LOS.ContractRegistry.psm1`
  - `los/registries/LOS.SchemaRegistry.psm1`
  - `los/registries/LOS.ArtifactLoader.psm1`
  - `los/registries/LOS.AttestationRegistry.psm1`
  - `los/reports/Phase-2.5-Governance-Report.md`

## Planned

- M2.7 documentation/state updates are not implemented as a milestone.
- M2.7 layer scaffold documentation remains planned unless backed by implementation evidence.
- Audit issue automation documentation may reference existing files under `ekos/audit/`, but that does not certify M2.7 completion.

## Not Yet Implemented (Documented Future)
- Phase 2.6 Governance Enforcement: NOT STARTED
- `los/registries/LOS.GovernanceValidator.psm1`
- Runtime enforcement gate
- Contract-required execution
- Execution certification pipeline

## Blocked

- Phase 3 Runtime Certification: BLOCKED until Phase 2.6 Governance Enforcement is complete.
