# PETOS

## 1) Purpose
PETOS (Application Layer) hosts application experiences and application-facing modules (Security+, CS50, PBQ, UI).

## 2) Ownership boundary
- Owns application-facing programs and UI integration.
- Uses LOS-certified contracts and EKOS execution engine without owning their core invariants.

## 3) What belongs here
- security-plus: Security+ program scaffolds
- cs50: CS50 program scaffolds
- pbq: PBQ program scaffolds
- ui: UI scaffolds and interfaces

## 4) What does NOT belong here
- EKOS deterministic execution engine internals
- LOS certified truth kernels
- training compute infrastructure implementation

## 5) Next build items
- Add Security+ MVP entry points and UI routing scaffolds.

