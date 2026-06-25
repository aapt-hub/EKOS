# EAi Reference Architecture

This is the canonical frozen architecture reference for EAi.

See [architecture.md](../architecture.md) for the implementation-ready master version.

## Frozen Structure

```text
EAi
├── EAi.Constitution
├── EAi-S Enterprise Engineering Standard
├── EAi.ReferenceArchitecture
├── EAi.Governance
├── EAi.Methodology
├── EAi.EngineeringToolchain
├── EAi.Knowledge
├── Enterprise Graph Kernel (EGK)
├── Enterprise Capability Kernel (ECK)
├── Enterprise Digital Twin (EDTi)
├── Enterprise Service Fabric (ESF)
├── Platform Products
├── Business Platform
├── Industry Solutions
└── Deployment Models
```

## Responsibility Summary

- EGK owns graph infrastructure only.
- ECK owns capability governance only.
- EDTi owns enterprise state only.
- ESF exposes governed enterprise services only.
- Platform products consume architecture.
- Business modules remain modular.
- Industry solutions are composed from business modules.
- Deployment models are documented and governed.

## Standard References

- [Governance](../governance.md)
- [Methodology](../methodology.md)
- [Roadmap](../roadmap.md)
- [Master Prompt](../master-prompt.md)

