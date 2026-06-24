# Execution Broker

The execution broker is implemented in `los/modules/LOS.ExecutionBroker.psm1`.

It coordinates contract, schema, attestation, policy, and provenance gates. Any failed gate returns a deny result.

Author: Abner Pauneto
