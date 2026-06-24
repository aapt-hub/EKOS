---
title: LOS DCEK Architecture Map
author: Abner Pauneto
project: EKOS
repository_status: Private Development
license: Proprietary
copyright: Copyright (c) 2026 Abner Pauneto
last_updated: 2026-06-24
---

# LOS DCEK Architecture Map

This page documents existing DCEK graph/tool harness modules under `graph/tools/`.
It does not mean Phase 2.6 Governance Enforcement, Phase 3 Runtime Certification,
the LOS governance validator, or repository-wide runtime blocking is implemented.

## Stabilized Execution Path

The stabilized LOS DCEK certification path is:

```text
LOS.DCEK.CertificationHarness
  -> LOS.ExecutionLifecycleEnforcer
    -> LOS.ContractRuntimeBroker
      -> LOS.ContractSystem
```

Normal certification execution must enter through `Invoke-LifecycleExecution`.
The certification harness must not call `Invoke-ContractedExecution` in the
runtime broker directly during normal `Run-PS5Execution` or `Run-PS7Execution`.
Direct broker calls are reserved for negative fail-closed probes.

## Module Responsibilities

### LOS.DCEK.CertificationHarness

- Provides `Run-PS5Execution`, `Run-PS7Execution`, and certification probes.
- Generates deterministic child-process scripts for PS5 and PS7.
- Normal execution child scripts import `LOS.ExecutionLifecycleEnforcer` and call
  `Invoke-LifecycleExecution`.
- Converts lifecycle results into the existing capture shape:
  `Output`, `ExecutionTrace`, and `Attestation`.
- Preserves deterministic hashing and byte-identical parity checks.

### LOS.ExecutionLifecycleEnforcer

- Owns the PRE -> EXEC -> POST lifecycle.
- Performs preflight contract and compatibility checks.
- Mediates all normal calls into `LOS.ContractRuntimeBroker`.
- Requires postflight attestation, ledger, drift, parity, and audit validation.
- Returns `finalVerdict=CERTIFIED` only after the full lifecycle completes.

### LOS.ContractRuntimeBroker

- Owns the guarded syscall boundary into `LOS.ContractSystem`.
- Resolves and attests schemas through `LOS.ContractIntegrityGuard`.
- Normalizes runtime context before schema resolution.
- Enforces fail-closed caller authorization.

### LOS.ContractSystem

- Executes the contract operation under an integrity attestation.
- Performs preflight and postflight integrity checks.
- Validates input and output envelopes against the resolved schema.

### LOS.ContractIntegrityGuard

- Mediates schema resolution through `LOS.ContractSchemaRegistry`.
- Issues one-use attestations.
- Blocks forged, tampered, replayed, or out-of-sequence attestations.

### LOS.ContractSchemaRegistry

- Stores current in-module contract definitions.
- Resolves contract schemas by contract id, version, and canonical runtime context.
- Validates compatibility and schema proof metadata.

## Broker Fail-Closed Rules

`LOS.ContractRuntimeBroker` must remain fail-closed.

Allowed normal caller:

```text
graph/tools/LOS.ExecutionLifecycleEnforcer.psm1
module name: LOS.ExecutionLifecycleEnforcer
```

Authorization is based on PowerShell call-stack evidence and resolved script path.
The broker may tolerate host-specific call-stack metadata differences, but only
when a stack frame resolves to the trusted lifecycle enforcer module path under
the same tools directory.

The broker must continue to block:

- Direct console calls to `Invoke-ContractedExecution`.
- Direct certification harness calls to `Invoke-ContractedExecution`.
- Calls from any module path other than the trusted lifecycle enforcer.

## Runtime Normalization

Schema resolution requires canonical runtime context keys:

```powershell
[pscustomobject]@{
    Runtime   = 'PS5'
    Edition   = 'Desktop'
    PSVersion = '5.1'
}
```

```powershell
[pscustomobject]@{
    Runtime   = 'PS7'
    Edition   = 'Core'
    PSVersion = '7.0'
}
```

The broker canonicalizer accepts hashtable or object input, but forwards only the
canonical `Runtime`, `Edition`, and `PSVersion` shape into schema resolution.
Do not reintroduce `PowerShellEdition` or `PowerShellVersion`.

## Smoke Test

Run from the repository root:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\graph\tests\Test-LOS-DCEK-Smoke.ps1
```

or:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\graph\tests\Test-LOS-DCEK-Smoke.ps1
```

The smoke test validates:

- Required LOS modules import successfully.
- `Invoke-LifecycleExecution` returns `CERTIFIED`.
- `Run-PS5Execution` returns `Completed` and `CERTIFIED`.
- `Run-PS7Execution` returns `Completed` and `CERTIFIED`, or reports an
  environment skip if PS7 cannot launch.
- Direct broker invocation remains blocked.
- The normal certification child path does not call the runtime broker directly.
- `graph/tools/LOS*` files do not contain `PowerShellEdition` or
  `PowerShellVersion`.
- `graph/tools/LOS*` files do not contain unsafe `.Contains(` usage.

## Known PS7 WindowsApps Shim Skip

On some Windows environments, `pwsh.exe` resolves to the WindowsApps shim and
cannot be launched by the certification child-process harness. In that case the
smoke test reports a PS7 environment skip, commonly with an error such as:

```text
The file cannot be accessed by the system
```

This skip means the local PS7 executable could not be started. It is not a LOS
contract-resolution failure and should not be reported as
`ContractResolved=False` or `SchemaLoaded=False`.

## Next Target

Externalize contract schemas from modules into:

```text
/los/contracts
```

The next phase should move contract definitions out of
`LOS.ContractSchemaRegistry.psm1` while preserving:

- Deterministic schema loading.
- Canonical runtime-context resolution.
- Compatibility matrix validation.
- IntegrityGuard attestation flow.
- Broker fail-closed authorization.
- Existing smoke-test behavior.
