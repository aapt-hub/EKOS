# LOS Governance — Phase 2.5 (Documentation Sync)

Repository implementation is the source of truth. Documentation must not describe planned milestones as implemented unless matching source artifacts exist.

## Phase 2.5 Objectives
- Provide a minimal, deterministic **LOS governance foundation** for certified artifacts.
- Implement registries for contracts and schemas.
- Implement artifact loading + hashing.
- Implement persistent attestation artifact generation.
- Provide governance report generation.

## Implemented Artifacts (in-repo)
- Contracts
  - `los/contracts/EKOS.Execute/1.0.0/contract.json`
- Schemas
  - `los/schemas/execution-result/1.0.0/schema.json`
- Attestations
  - `los/attestations/contract/EKOS.Execute/1.0.0/attestation.json`
- Governance report
  - `los/reports/Phase-2.5-Governance-Report.md`

## Implemented Registries / Modules (in-repo)
- `los/registries/LOS.ContractRegistry.psm1`
- `los/registries/LOS.SchemaRegistry.psm1`
- `los/registries/LOS.ArtifactLoader.psm1`
- `los/registries/LOS.AttestationRegistry.psm1`

## Attestation Storage
- Attestation content is stored as deterministic JSON under `los/attestations/...`.
- Governance report references the attestation path.

## Governance Report Generation
- `los/reports/Phase-2.5-Governance-Report.md` indicates PASS and lists:
  - Registered contracts
  - Registered schemas
  - Registry modules used
  - Produced attestation artifacts

## Artifact Lifecycle (documented view)
1. Contract retrieval: locate `los/contracts/<ContractId>/<Version>/contract.json`
2. Schema retrieval: locate `los/schemas/<SchemaId>/<Version>/schema.json`
3. Artifact hashing: compute SHA256 for loaded JSON artifacts
4. Attestation generation: create an attestation JSON with artifact hash metadata
5. Governance report generation: summarize registrations + attestation artifacts

## Known Gaps (Future Work)
**Not Yet Implemented (documented future):**
- `los/registries/LOS.GovernanceValidator.psm1`
- Runtime enforcement gate
- Contract-required execution
- Execution certification pipeline
- Phase 2.6 Governance Enforcement
- Phase 3 Runtime Certification, blocked until Phase 2.6 is complete


