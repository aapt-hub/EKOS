# DEVICEi

DEVICEi is the ATOMIx Enterprise Device Platform.

Current status: documentation and contracts only. No runtime service, no database, no API implementation, and no endpoint agent implementation exist in this milestone.

## Responsibility

DEVICEi owns enterprise device enrollment, identity, inventory, compliance, patch state, lifecycle, configuration, endpoint management, hardware identity, asset intelligence, Puppet integration, Ansible compatibility, and future endpoint agent architecture.

## Contract Boundary

DEVICEi extends the Kernel. It does not redefine enterprise asset identity, relationships, policies, capabilities, events, telemetry, lifecycle, governance, or intelligence.

Every device is an Enterprise Asset in the Enterprise Graph. Device intelligence comes from graph relationships, telemetry, compliance state, lifecycle state, policies, and linked capabilities.

## Deployment Direction

DEVICEi is Puppet-first for enterprise configuration and deployment modeling, with Ansible compatibility for organizations that require Ansible playbooks or transitional operations.

The future DEVICEi Agent technology direction is Go, but agent implementation belongs to a later runtime phase after documentation, contracts, schemas, registries, validation, tests, graph integration contracts, and certification gates are complete.

## M3.3 Foundation Scope

- Enrollment contracts.
- Hardware identity contracts.
- Inventory schemas.
- Compliance and patch state schemas.
- Lifecycle registry entries.
- Configuration policy references.
- Puppet integration contracts.
- Ansible compatibility contracts.
- Endpoint agent architecture documentation.

## Registry Planning

M3.2 and M3.3 must register DEVICEi capabilities, lifecycle states, policy bindings, Puppet integration points, and Ansible compatibility references before runtime exists.
