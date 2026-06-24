# LOS

LOS is the Operating System Truth Kernel for EKOS.

## Purpose

LOS owns truth contracts, schemas, attestations, governance enforcement, runtime certification, runtime trust authority, continuous trust monitoring, and runtime trust enforcement.

## Current Runtime Chain

```text
Contract
-> Schema
-> Attestation
-> Policy
-> Execution Broker
-> Runtime Execution
-> Certification
-> Trust Authority
-> Trust Monitoring
-> Trust Enforcement
```

## Implemented Milestones

- M2.6 Governance Enforcement
- M2.7 Runtime Certification
- M2.8 Runtime Trust Authority
- M2.9 Runtime Trust Monitoring
- M2.10 Runtime Trust Enforcement

## Subsystems

### Governance Enforcement

Located under `los/modules/`.

- `LOS.ContractEnforcer.psm1`
- `LOS.PolicyEngine.psm1`
- `LOS.ExecutionBroker.psm1`
- `LOS.ProvenanceEngine.psm1`
- `LOS.ComplianceReport.psm1`

### Runtime Certification

Located under `los/certification/`.

- `CertificationEvidence.psm1`
- `CertificationHarness.psm1`
- `CertificationLedger.psm1`
- `CertificationReport.psm1`
- `CertificationParity.psm1`
- `CertificationFailureTaxonomy.psm1`

### Runtime Trust

Located under `los/trust/`.

- `LOS.RuntimeTrustAuthority.psm1`
- `LOS.TrustEvidence.psm1`
- `LOS.TrustDecision.psm1`
- `LOS.TrustLedger.psm1`
- `LOS.TrustReport.psm1`
- `LOS.TrustScoring.psm1`
- `LOS.TrustAlerts.psm1`
- `LOS.RuntimeTrustMonitor.psm1`
- `LOS.RuntimeTrustEnforcement.psm1`

## Tests

```powershell
Import-Module Pester -MinimumVersion 5.0 -Force
Invoke-Pester .\los\tests\ -Output Minimal
```

## Ownership Boundary

LOS does not own PETOS application behavior or host OS implementation. It provides the truth and authority layer consumed by EKOS and PETOS.

Author: Abner Pauneto  
Project: EKOS  
Repository: https://github.com/aapt-hub/EKOS  
License: MIT
