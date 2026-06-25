# Kernel Schemas

Kernel schemas define the common Enterprise Asset model for ATOMIx.

This is documentation and contract material only. It introduces no runtime service, database, API, endpoint agent, executable validator, or business logic.

## Canonical Schemas

- Enterprise Asset.
- Identity.
- Relationship.
- Policy Binding.
- Capability Binding.
- Event.
- Telemetry.
- Lifecycle.
- Governance.
- Intelligence.

## Rule

Every platform module extends Kernel schemas. Modules must not redefine identity, relationship, policy, capability, event, telemetry, lifecycle, governance, or intelligence concepts.

## M3.2 Gate

M3.2 is complete only when schema documentation and schema references are traceable to Kernel contracts and registries.

