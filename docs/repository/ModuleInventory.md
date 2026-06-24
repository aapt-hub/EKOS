---
title: Module Inventory
author: Abner Pauneto
project: EKOS
repository_status: Private Development
license: Proprietary
copyright: Copyright (c) 2026 Abner Pauneto
last_updated: 2026-06-24
---

# Module Inventory

## Purpose

Inventory of EKOS-owned PowerShell modules relevant to current LOS and EKOS runtime authority work.

## LOS Governance Modules

- `los/modules/LOS.ContractEnforcer.psm1`: validates contract presence, identity, schema reference, and contract hash.
- `los/modules/LOS.PolicyEngine.psm1`: evaluates runtime policy and deterministic policy hash.
- `los/modules/LOS.ExecutionBroker.psm1`: coordinates governance gates and provenance creation.
- `los/modules/LOS.ProvenanceEngine.psm1`: creates canonical governance provenance records.
- `los/modules/LOS.ComplianceReport.psm1`: emits structured governance compliance JSON.

## LOS Certification Modules

- `los/certification/CertificationEvidence.psm1`: creates certification evidence.
- `los/certification/CertificationHarness.psm1`: orchestrates certification checks.
- `los/certification/CertificationLedger.psm1`: writes and reads certification ledger entries.
- `los/certification/CertificationReport.psm1`: emits certification reports.
- `los/certification/CertificationParity.psm1`: validates evidence parity.
- `los/certification/CertificationFailureTaxonomy.psm1`: normalizes certification failure categories.

## LOS Trust Modules

- `los/trust/LOS.RuntimeTrustAuthority.psm1`: evaluates runtime trust authority.
- `los/trust/LOS.TrustEvidence.psm1`: creates trust evidence and deterministic hashes.
- `los/trust/LOS.TrustDecision.psm1`: evaluates trust decisions.
- `los/trust/LOS.TrustLedger.psm1`: manages trust ledger records and compatibility wrappers.
- `los/trust/LOS.TrustReport.psm1`: emits trust reports.
- `los/trust/LOS.TrustScoring.psm1`: calculates trust scores.
- `los/trust/LOS.TrustAlerts.psm1`: writes, reads, and resolves trust alerts.
- `los/trust/LOS.RuntimeTrustMonitor.psm1`: performs monitoring passes and health reporting.
- `los/trust/LOS.RuntimeTrustEnforcement.psm1`: applies quarantine, deny, and revoke enforcement state.
- `los/trust/LOS.TrustRecovery.psm1`: manages LOS-TRUST-004 recovery requests, approval, revalidation, trust authority review, and recovery ledger events.

## EKOS Runtime Modules

- `graph/tools/EKOS.CanonicalSerializer.psm1`: deterministic canonical JSON serializer.
- `graph/tools/EKOS.GraphRuntime.psm1`: graph runtime support.
- `ekos/audit/*.psm1`: EKOS audit orchestration and GitHub issue reporting.

## Current Maturity

LOS runtime authority is implemented through M2.11. M2.12 through M2.13 and Phase 3 remain planned.

Author: Abner Pauneto  
Project: EKOS  
Repository: EKOS  
License: Proprietary - All Rights Reserved
