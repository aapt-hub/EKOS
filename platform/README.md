# Platform

This folder is the EAi platform skeleton.

## Core Components

- `LOSi`
- `EKOSi`
- `CONTROLi`
- `INDEXi`
- `FACTORYi`
- `PROVIDERi`
- `CONSOLEi`
- `SDKi`
- `USEROBSERVEi`

## Notes

- `INDEXi` and `FACTORYi` remain structure and planning services unless runtime is explicitly approved.
- All provider integrations must route through `PROVIDERi`.
- All runtime decisions must be policy-checked by `LOSi`.
