---
sidebar_position: 5
title: Governance
draft: true
---

# Governance

Quantus uses the Polkadot OpenGov governance model, adapted for a proof-of-work chain. Governance enables forkless runtime upgrades -- critical for a chain that may need to swap cryptographic primitives as PQC standards evolve.

## Why Forkless Upgrades Matter

If NIST deprecates ML-DSA-87 or a vulnerability is found in Poseidon2, Quantus can upgrade its runtime via on-chain governance without coordinating a hard fork. The Substrate framework compiles the runtime to WASM, and governance can schedule a runtime swap that all nodes automatically adopt.

This is the key advantage over Bitcoin's upgrade model, where consensus changes require years of social coordination and miner signaling.

## Technical Collective

A group of technically qualified members who can fast-track urgent protocol upgrades (security patches, critical bug fixes). The Technical Collective has its own referendum track with lower thresholds and shorter voting periods, enabling rapid response to security issues.

## Governance Components

| Pallet | Purpose |
|--------|---------|
| `pallet-referenda` | Referendum management |
| `pallet-referenda::Instance1` | Technical Collective referenda |
| `pallet-conviction-voting` | Conviction-weighted vote tallying |
| `pallet-ranked-collective` | Technical Collective membership |
| `pallet-preimage` | Stores referendum proposal data |
| `pallet-scheduler` | Executes approved referenda at scheduled blocks |

## Key Source Code

| Component | Path |
|-----------|------|
| Governance track definitions | `runtime/src/governance/definitions.rs` |
| Runtime configuration | `runtime/src/configs/mod.rs` |
| Scheduler (custom) | `pallets/scheduler/` |
