# Provider Governance

`PROVIDERi` is the only approved provider abstraction.

## Provider Categories

- AI
- cloud
- database
- messaging
- identity

## Rules

- no application may connect directly to a provider
- all provider usage must route through `PROVIDERi`
- all runtime decisions must be policy-checked by `LOSi`
- all provider usage must be explainable and auditable

## AI Provider Direction

- engineering can use approved multi-provider AI
- customer-facing modules default to private providers
- public provider use is policy controlled
