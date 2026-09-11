---
sidebar_position: 5
title: Governance
draft: true
---

# Governance

Quantus governance is a **technical collective** that can pass runtime upgrades through tech referenda. The public conviction-voting / token-weighted lane was removed. Forkless WASM upgrades still matter: if NIST deprecates ML-DSA-87 or a Poseidon2 issue appears, the collective can schedule a runtime swap without a hard fork.

## Technical Collective

A ranked collective of technically qualified members. They submit and vote on tech referenda (security patches, parameter changes, runtime upgrades). Tracks and curves are runtime constants — see `docs/TECH_COLLECTIVE_GOVERNANCE_TUNING.md` in the chain repo.

Mainnet seeds 10 collective members (distinct from the 10 treasury signers). The treasury is a 6-of-10 multisig of those treasurers and is **not** paid from block rewards.

## Governance Components

| Pallet | Purpose |
|--------|---------|
| `pallet-ranked-collective` | Technical Collective membership |
| `pallet-referenda` (Instance1, `TechReferenda`) | Technical Collective referenda |
| `pallet-preimage` | Stores referendum proposal data |
| `pallet-scheduler` | Executes approved referenda (user scheduler calls are disabled) |
| `pallet-custom-origins` | Dispatch origins for non-Root tech-referenda tracks (e.g. `FastUpgrade`) |
| `pallet-treasury` | 6-of-10 treasury multisig |

Removed (vacant pallet indices): community `Referenda`, `ConvictionVoting`, `pallet-sudo`, `pallet-recovery`.

## Key Source Code

| Component | Path |
|-----------|------|
| Runtime pallet list | `runtime/src/lib.rs` |
| Runtime configuration | `runtime/src/configs/mod.rs` |
| Scheduler (custom, calls disabled) | `pallets/scheduler/` |
