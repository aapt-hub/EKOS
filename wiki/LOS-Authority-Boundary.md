# LOS Authority Boundary and Enforcement Gates

Repository implementation is the source of truth. Documentation must not describe planned milestones as implemented unless matching source artifacts exist.

## Purpose

The Lifecycle Operating System (LOS) is the governance authority for the EKOS ecosystem.

LOS defines, validates, and governs the execution lifecycle through contracts, schemas, attestations, policies, and certification requirements.

EKOS is an execution engine and must not independently override governance decisions established by LOS.

## Authority Boundary

LOS is the authoritative source for:

- Contract definitions
- Schema definitions
- Artifact identity
- Artifact provenance
- Attestation validation
- Policy decisions
- Certification requirements

EKOS is responsible for:

- Runtime execution
- Runtime orchestration
- Deterministic processing
- Transaction management
- Execution auditing
- Runtime evidence generation

EKOS does not possess governance authority.

## Implemented Authority Surface

Phase 2.5 Governance Foundation is complete and provides these repository-backed artifacts:

- `los/contracts/EKOS.Execute/1.0.0/contract.json`
- `los/schemas/execution-result/1.0.0/schema.json`
- `los/attestations/contract/EKOS.Execute/1.0.0/attestation.json`
- `los/reports/Phase-2.5-Governance-Report.md`
- `los/registries/LOS.ContractRegistry.psm1`
- `los/registries/LOS.SchemaRegistry.psm1`
- `los/registries/LOS.ArtifactLoader.psm1`
- `los/registries/LOS.AttestationRegistry.psm1`

## Planned Governance Chain

The following governance chain is the planned Phase 2.6 enforcement model. It is not implemented yet.

```text
Execution Request
        |
        v
LOS.ArtifactLoader
        |
        v
LOS.ContractRegistry
        |
        v
LOS.SchemaRegistry
        |
        v
LOS.AttestationRegistry
        |
        v
LOS.PolicyEngine
        |
        v
LOS.ExecutionBroker
        |
        v
EKOS Runtime
```

No component may bypass any stage in this chain once Phase 2.6 governance enforcement is implemented.

## Planned Enforcement Gates

The following gates are mandatory for the planned Phase 2.6 enforcement model. They are not implemented yet.

### Gate 1 - Contract Validation

Requirements:

- Contract must exist.
- Contract version must exist.
- Contract must be loadable.
- Contract must be valid.

Failure result:

```text
DENY
```

### Gate 2 - Schema Validation

Requirements:

- Schema must exist.
- Schema version must exist.
- Schema must validate.
- Contract and schema versions must be compatible.

Failure result:

```text
DENY
```

### Gate 3 - Attestation Validation

Requirements:

- Attestation record must exist.
- Attestation must be valid.
- Attestation must match artifact identity.
- Integrity verification must pass.

Failure result:

```text
DENY
```

### Gate 4 - Policy Evaluation

Requirements:

- Policy rules must evaluate successfully.
- Required capabilities must be present.
- Execution context must be authorized.

Failure result:

```text
DENY
```

### Gate 5 - Broker Authorization

Requirements:

- Request must originate from the approved governance path.
- Request must contain governance metadata.
- Request must pass all prior gates.

Failure result:

```text
DENY
```

## Planned Fail-Closed Model

LOS governance enforcement will operate using a fail-closed model.

If governance state cannot be determined, execution shall be denied.

Examples:

- Missing contract
- Missing schema
- Missing attestation
- Unknown version
- Registry load failure
- Policy evaluation failure
- Integrity verification failure

Result:

```text
DENY
```

## Runtime Certification Boundary

Phase 3 Runtime Certification depends upon successful completion of all governance enforcement gates.

Certification evidence is valid only when execution occurs through the approved governance path.

Direct runtime execution is not certification-valid.

## Planned Provenance Requirements

Every governed execution shall produce provenance evidence once Phase 2.6 governance enforcement exists.

Minimum evidence fields:

- ContractId
- ContractVersion
- ContractHash
- SchemaHash
- PolicyHash
- AttestationHash
- Runtime
- InputHash
- OutputHash
- Decision
- TimestampUtc

These records form the planned certification evidence chain.

## Phase Responsibilities

### Phase 2.5 Governance Foundation

Provides:

- Contracts
- Schemas
- Registries
- Attestations
- Governance artifacts

Status:

```text
COMPLETE
```

### Phase 2.6 Governance Enforcement

Provides:

- Enforcement gates
- Policy evaluation
- Execution authorization
- Broker enforcement
- Fail-closed execution control

Status:

```text
NOT STARTED
```

### Phase 3 Runtime Certification

Provides:

- Certification evidence
- Runtime validation
- Provenance verification
- Certification reporting

Status:

```text
BLOCKED
```
