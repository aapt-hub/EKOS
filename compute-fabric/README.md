---
title: Compute Fabric
author: Abner Pauneto
project: EKOS
repository_status: Private Development
license: Proprietary
copyright: Copyright (c) 2026 Abner Pauneto
last_updated: 2026-06-24
---

# Compute Fabric

## 1) Purpose
Compute Fabric provides the infrastructure scaffolding for running training/inference jobs: Docker, Kubernetes, GPU configuration, Ollama integration, storage, and networking.

## 2) Ownership boundary
- Owns environment deployment and runtime compute configuration.
- Does **not** implement deterministic execution logic (EKOS), nor certified truth kernels (LOS).

## 3) What belongs here
- docker: Docker scaffolds
- kubernetes: K8s deployment scaffolds
- gpu: GPU capability/workload scaffolds
- ollama: Ollama model runtime scaffolds
- storage: storage layouts
- networking: network policy scaffolds

## 4) What does NOT belong here
- Audit orchestration modules
- LOS contracts and schema definitions
- training dataset definitions (belongs to Training Fabric)

## 5) Next build items
- Add environment templates and minimal runnable docker-compose/k8s manifests.

