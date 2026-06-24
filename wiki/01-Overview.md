# Overview

EKOS is organized into four layers:

- LOS = Operating System Truth Kernel
- EKOS = Runtime Execution Engine
- PETOS = Application Layer
- Linux / Windows = Host Runtime Layer

The current LOS runtime authority chain is implemented through M2.10:

```text
Contract -> Schema -> Attestation -> Policy -> Execution Broker -> Runtime Execution -> Certification -> Trust Authority -> Trust Monitoring -> Trust Enforcement
```

Author: Abner Pauneto
