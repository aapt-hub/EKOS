# Runtime Control Guardrails

## Guardrails

- No automation may self-expand scope.
- No recursive self-modification.
- Human approval is required before production changes.
- All generated modules must pass controller tests.
- All provider integrations must go through `PROVIDERi`.
- All runtime decisions must be policy-checked by `LOSi`.
- All recommendations must be explainable and auditable.

## Cadence

- Monthly review for normal changes.
- Weekly review for critical items only.

## Promotion

- strict dev/test/prod promotion
- controller-gated lifecycle
