# EKOS

## 1) Purpose
EKOS (Deterministic Execution Engine) implements deterministic execution, ingestion, knowledge fabric integration, meta-compilation, reporting, and audit orchestration.

## 2) Ownership boundary
- Owns deterministic runtime and execution orchestration.
- Owns EKOS-layer audit modules and result reporting hooks.
- Does **not** define certified truth contracts; those belong to LOS.
- Does **not** define training or compute infrastructure implementation; those belong to their fabrics.

## 3) What belongs here
- runtime: runtime host abstractions and deterministic execution entry points
- graph: graph execution orchestration (without rewriting existing graph tools)
- ingestion: ingestion pipeline scaffolds
- knowledge-fabric: knowledge integration scaffolds
- meta-compiler: deterministic plan/meta compilation scaffolds
- test-runner: test execution scaffolds
- reporting: reporting scaffolds
- audit: audit orchestration + audit failure GitHub issue reporting

## 4) What does NOT belong here
- LOS certified truth schemas and contract integrity invariants
- training datasets/model evaluation artifacts
- compute fabric (Docker/K8s/GPU/Ollama)
- host abstraction OS-specific logic beyond HAL boundary

## 5) Next build items
- Introduce ingestion engine MVP and wire it to test-runner.
- Add richer audit invariant types and structured audit result schemas.

