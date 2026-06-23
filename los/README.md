# LOS

## 1) Purpose
LOS (Certified Truth Kernel) is the repository’s source of truth for certified contracts, schemas, identity, certification, attestation, ledger, and provenance.

## 2) Ownership boundary
- Owns LOS-layer data contracts and validation primitives.
- Owns certified artifacts and their invariants.
- Does **not** own runtime execution logic, graph execution, or external orchestration.

## 3) What belongs here
- contracts: contract definitions and interfaces
- schemas: schema definitions and schema validation rules
- identity: identity models and identity verification contracts
- certification: certification procedures/invariants
- attestation: attestation models and attestations invariants
- ledger: ledger models and ledger invariants
- provenance: provenance models and lineage invariants

## 4) What does NOT belong here
- EKOS runtime/graph/inference/ingestion code
- GitHub automation or operational audit orchestration
- training pipelines, model evaluation, or compute infrastructure

## 5) Implemented (Phase 2.5) — Governance Foundation

### Contracts
- `los/contracts/EKOS.Execute/1.0.0/contract.json`

### Schemas
- `los/schemas/execution-result/1.0.0/schema.json`

### Artifact Loader + Hashing
- `los/registries/LOS.ArtifactLoader.psm1`

### Attestation System
- Attestations are stored under `los/attestations/...`
- Example:
  - `los/attestations/contract/EKOS.Execute/1.0.0/attestation.json`

### Governance Reporting
- `los/reports/Phase-2.5-Governance-Report.md`

### Implemented LOS Registry Modules
- `los/registries/LOS.ContractRegistry.psm1`
- `los/registries/LOS.SchemaRegistry.psm1`
- `los/registries/LOS.ArtifactLoader.psm1`
- `los/registries/LOS.AttestationRegistry.psm1`

## 6) Not Yet Implemented

- `los/registries/LOS.GovernanceValidator.psm1`
- Runtime enforcement gate
- Contract-required execution
- Execution certification pipeline
- Phase 2.6 Governance Enforcement
- Phase 3 Runtime Certification

Phase 3 Runtime Certification is blocked until Phase 2.6 Governance Enforcement is complete.

