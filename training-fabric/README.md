---
title: Training Fabric
author: Abner Pauneto
project: EAi
repository_status: Private Development
license: Proprietary
copyright: Copyright (c) 2026 Abner Pauneto
last_updated: 2026-06-25
---

# Training Fabric

Training Fabric is the legacy dataset and evaluation scaffolding layer under EAi 2.0.

## 1) Purpose
Training Fabric contains datasets, evaluation harnesses, registries, checkpoints, and preparation steps (LoRA/quantization prep) used by PETOS systems.

## 2) Ownership boundary
- Owns ML training-evaluation scaffolds and artifact organization.
- Does **not** own compute infrastructure runtime; that belongs to Compute Fabric.
- Does **not** own certified contracts; that belongs to LOS.

## 3) What belongs here
- datasets: curated dataset collections
- registry: dataset/model registry scaffolds
- eval: evaluation definitions and runner scaffolds
- model-registry: model artifact index
- checkpoints: checkpoint storage layout
- lora: LoRA preparation scaffolds
- quantization: quantization preparation scaffolds

## 4) What does NOT belong here
- GitHub automation for audits
- EKOS runtime execution engine
- compute implementation (Docker/Kubernetes/GPU/Ollama)

## 5) Next build items
- Establish dataset manifest schema.
- Add evaluation configuration scaffolds.

