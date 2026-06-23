# EKOS
EKOS (Enterprise Engineering Knowledge Operating System)
=======
﻿# EKOS / PETOS

Enterprise Engineering Knowledge Operating System

- PETOS = Personal Engineering System
- EKOS = Enterprise Engineering System

This repository contains structured engineering knowledge:
stacks, patterns, architectures, ADRs, runbooks, and more.


# EKOS.Graph v3

EKOS.Graph v3 is a modular, deterministic graph query and execution engine built in PowerShell. It provides AI-style query interpretation, optimization, planning, and transactional execution over graph structures.

---

## 🚀 Overview

EKOS.Graph v3 supports:

- Natural language or structured graph queries
- Deterministic execution pipeline
- Query optimization and cost shaping
- Execution planning layer
- Transaction-safe graph operations (WAL-ready design)
- CLI and REST interfaces

---

## 🧠 Core Pipeline

All queries flow through a strict deterministic pipeline:

Query
↓
Parser
↓
Normalizer
↓
Optimizer
↓
Planner
↓
Executor
↓
Transaction Engine
↓
Post Validator

Each layer is isolated and must not mutate other layers.

---

## 📦 Architecture

EKOS.Graph
│
├── Bootstrap
│   └── ModuleLoader.ps1
│
├── Engine
│   ├── GraphCore.ps1
│   ├── QueryEngine.ps1
│   ├── QueryParser.ps1
│   ├── QueryNormalizer.ps1
│   ├── Optimizer/
│   │   └── QueryOptimizer.psm1
│   ├── Planner/
│   │   └── QueryPlanner.psm1
│   ├── Executor.ps1
│   └── TransactionEngine.ps1
│
├── Storage
│   ├── WAL/
│   └── Snapshots/
│
└── Tests

---

## ⚙️ Core Entry Point

Invoke-EKOSQuery @{
    text = "find deep path from A to E"
    type = "Search"
}

---

## 🧪 Debug Mode

Invoke-EKOSQuery @{
    text = "find node A"
    type = "Search"
    debug = $true
}

Debug mode exposes:
- Parsed query
- Normalized query
- Optimized query
- Execution plan
- Final result

---

## 🧠 Query Types

Search
- Finds nodes matching conditions
- type = "Search"

Traverse
- Navigates paths between nodes
- type = "Traverse"

Query
- Direct node inspection
- type = "Query"

---

## 🧩 QueryOptimizer

The optimizer transforms queries before planning.

Responsibilities:
- Query rewriting (aliases, normalization)
- Filter cleanup
- Edge pruning (duplicates, self-loops)
- Cost model assignment
- Traversal strategy selection

Example output:

@{
    text = "search deep path"
    type = "Search"
    filters = @("status=active")
    edges = @(
        @{ from = "A"; to = "B" }
    )
    _cost_model = @{
        traversal = "dfs"
        depth_limit = 20
        fanout_limit = 100
    }
}

---

## 🧭 QueryPlanner

The planner converts optimized queries into execution plans.

Responsibilities:
- Define execution steps
- Interpret cost model
- Select traversal strategy

Example plan:

@{
    operation = "Search"
    traversal = "dfs"
    execution_steps = @(
        "load_root",
        "traverse",
        "apply_filters",
        "return_results"
    )
}

---

## 💻 CLI Usage

Invoke-EKOSQuery -Text "find node A"

Invoke-EKOSQuery @{
    text = "find active nodes"
    type = "Search"
}

Invoke-EKOSQuery @{
    text = "test graph"
    debug = $true
}

---

## 🌐 REST API (v3)

POST /api/v3/query

Request:

{
  "text": "find deep path A to E",
  "type": "Search",
  "filters": ["status=active"],
  "debug": false
}

Response:

{
  "result": {
    "nodes": [],
    "edges": [],
    "path": []
  },
  "metadata": {
    "execution_time_ms": 12,
    "traversal": "dfs"
  }
}

GET /api/v3/health

Response:

{
  "status": "healthy",
  "engine": "EKOS.Graph v3.0.0"
}

---

## 🔁 Execution Modes

Development Mode:
- Full debug output
- Pipeline visibility
- Optimizer trace enabled

Production Mode:
- Minimal logging
- Optimized execution
- Transaction-safe commits only

---

## 🧪 Testing

Test optimizer only:

Invoke-QueryOptimizer -Normalized @{
    text = "find deep path"
    type = "Search"
}

Test full pipeline:

Invoke-EKOSQuery @{
    text = "test node A"
    type = "Search"
} -debug

---

## 🧱 Design Principles

- Deterministic execution
- Strict module separation
- No cross-layer mutation
- Query transformation before execution
- Transaction-safe graph updates (WAL design)

---

## 🛣️ Roadmap

## Phase Status (Documentation)

Repository implementation is the source of truth. Documentation must not describe planned milestones as implemented unless matching source artifacts exist.

- Phase 2.5 — **LOS Governance Foundation: COMPLETE**
- Phase 2.6 — Governance Enforcement: NOT STARTED
- Phase 3 — Runtime Certification: BLOCKED until Phase 2.6 is complete

---

## Next EKOS.Graph v3 Build Items (Existing docs)

v3.1:
- Adaptive cost tuning
- Query caching layer
- Hot-path detection

v3.2:
- Parallel traversal engine
- Lock manager
- Concurrency control

v3.3:
- WAL replay system
- Snapshot restore engine
- Crash recovery validation

v4:
- Distributed graph shards
- Multi-node execution engine

---

## 📌 Summary

EKOS.Graph v3 provides:

- AI-style query interpretation
- Optimized traversal planning
- Modular PowerShell architecture
- CLI + REST interfaces
- Transaction-safe execution model

---

## 🧠 Core Rule

All queries must pass through:

Parser → Normalizer → Optimizer → Planner → Executor

No direct execution outside the Executor layer is allowed.
