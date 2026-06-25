# ADR-0002 Graph Kernel

## Status

Accepted

## Decision

EGK owns graph infrastructure only.

## Consequences

- Graph storage, traversal, indexing, transactions, versioning, and integrity remain under EGK.
- Business logic, AI, policies, and scheduling remain outside EGK.
