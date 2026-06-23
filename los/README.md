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

## 5) Next build items
- Define first LOS SystemContract(s) and schema registry layout.
- Add certification + attestation model validators.

