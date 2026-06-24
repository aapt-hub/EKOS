---
title: Execution Broker
author: Abner Pauneto
project: EKOS
repository_status: Private Development
license: Proprietary
copyright: Copyright (c) 2026 Abner Pauneto
last_updated: 2026-06-24
---

# Execution Broker

The execution broker is implemented in `los/modules/LOS.ExecutionBroker.psm1`.

It coordinates contract, schema, attestation, policy, and provenance gates. Any failed gate returns a deny result.

Author: Abner Pauneto
