# HAL (Host Abstraction Layer)

## 1) Purpose
HAL abstracts host OS/runtime detection and platform-specific behavior into a stable boundary.

## 2) Ownership boundary
- Owns OS/runtime detection and host abstractions.
- Does **not** own business logic, contracts, or execution engine logic.

## 3) What belongs here
- linux: Linux detection + primitives
- windows: Windows detection + primitives
- powershell: PowerShell runtime helpers
- host-detection: shared host detection utilities

## 4) What does NOT belong here
- EKOS runtime and graph execution code
- GitHub audit issue automation
- Training/compute environment implementations

## 5) Next build items
- Add consistent host-detection API and unit smoke tests.

