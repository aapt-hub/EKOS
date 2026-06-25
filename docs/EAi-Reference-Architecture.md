# ATOMIx Enterprise Asset Intelligence Platform

ATOMIx is an Enterprise Asset Intelligence Platform.

Mission: One Kernel. One Graph. One Enterprise.

The platform is contract-first, graph-native, AI-assisted, and documentation-driven. Every enterprise asset shares a common model: identity, relationships, policies, capabilities, events, telemetry, lifecycle, governance, and intelligence.

## Enterprise Asset Intelligence

Everything is represented as an Enterprise Asset. People, devices, servers, applications, containers, databases, APIs, business capabilities, customers, suppliers, documents, AI models, facilities, vehicles, industrial equipment, and cloud resources all share one governed lifecycle.

## Immutable Principles

1. The Kernel owns only contracts. Never business logic, runtime behavior, or implementations.
2. Everything extends the Kernel. Modules never redefine core concepts.
3. One Enterprise Graph. Every asset is represented inside a graph and everything is connected.
4. Enterprise Intelligence comes from the Graph. EKOSi reasons over graph data, not isolated prompts.
5. Runtime is replaceable. Contracts define the platform. Runtime implements contracts.

## Enterprise Graph

The Enterprise Graph is the central knowledge model and system of understanding. It represents assets, relationships, dependencies, capabilities, policies, events, digital twins, and telemetry.

## Platform Modules

- Kernel: contracts, schemas, registries, validation, discovery.
- LOSi: identity, trust, authentication, authorization, governance, PKI, and policy.
- DEVICEi: enterprise device platform for enrollment, inventory, compliance, lifecycle, configuration, endpoint management, hardware identity, asset intelligence, Puppet integration, and Ansible compatibility. Current status: documentation and contracts only. No runtime and no agent implementation.
- CONTROLi: workflow, scheduling, automation, and orchestration.
- OBSERVEi: telemetry, logs, metrics, tracing, and health.
- SECURITYi: vulnerability management, risk, compliance, and incident response.
- EKOSi: AI, planning, optimization, recommendations, and knowledge graph enrichment.
- FACTORYi: repository generation, module generation, SDK, packaging, and CI/CD.
- PROVIDERi: external providers, cloud, AI providers, and SaaS integration.
- CONSOLEi: unified enterprise administration portal.

## DEVICEi Foundation

DEVICEi documents enrollment, identity, inventory, compliance, patch state, lifecycle, configuration, Puppet-first deployment, Ansible compatibility, and future endpoint agent architecture.

M3.3 DEVICEi Foundation is documentation and contracts only. Do not add a service, database, API implementation, endpoint agent, or executable infrastructure before documentation, contracts, schemas, registries, validation, tests, graph integration contracts, and certification are complete.

## Technology Strategy

- Kernel: C# and .NET.
- Graph: C#.
- LOSi: Rust.
- SECURITYi: Rust.
- CONTROLi: Go.
- DEVICEi Agent: Go, future only after contracts and certification.
- SDK / CLI: Go.
- AI Integration: Python adapters through PROVIDERi.
- Administration: PowerShell.
- Web: React + TypeScript.
- Primary Enterprise Linux: Rocky Linux.
- Configuration: Puppet with Ansible compatibility.
- Deployment: RPM, MSI, containers, and Kubernetes.

## Engineering Methodology

Development order is mandatory: documentation, contracts, schemas, registries, validation, tests, runtime, integration, certification, release.

Runtime implementation shall never precede documentation and contracts.

## Roadmap Alignment

- M3.0 Kernel Contracts.
- M3.1 Capability Contracts.
- M3.2 Schemas & Registries.
- M3.3 DEVICEi Foundation.
- M3.4 INDEXi Metadata.
- M3.5 Validation & Certification.
- M3.6 Graph Integration Contracts.
- M3.7 Runtime Host Abstraction.
- M4 Runtime Implementation.

## Legacy Material

Legacy EAi, EKOS, LOS, PETOS, EGK, ECK, EDTi, and ESF documents remain useful historical context where retained. They no longer override the ATOMIx Enterprise Asset Intelligence baseline.
