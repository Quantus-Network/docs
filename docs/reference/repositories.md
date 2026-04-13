---
sidebar_position: 1
title: Repository Map
---

# Repository Map

All Quantus Network source code lives in the [Quantus-Network](https://github.com/Quantus-Network) GitHub organization. This page catalogs every repository, organized by function.

Each repo links to GitHub and [DeepWiki](https://deepwiki.com) (AI-generated documentation for deeper code exploration).

## Core Protocol

The two main repositories containing the blockchain node and ZK proof system.

| Repository | Language | Description |
|------------|----------|-------------|
| [chain](https://github.com/Quantus-Network/chain) · [DeepWiki](https://deepwiki.com/Quantus-Network/chain) | Rust | Main blockchain node. Substrate-based with QPoW consensus, all pallets (wormhole, reversible transfers, multisig, governance, treasury), and mining infrastructure. |
| [qp-zk-circuits](https://github.com/Quantus-Network/qp-zk-circuits) · [DeepWiki](https://deepwiki.com/Quantus-Network/qp-zk-circuits) | Rust | Zero-knowledge proof circuits built on Plonky2. Contains the wormhole circuit (prover, verifier, aggregator), voting circuit, and shared ZK gadgets. |

## Cryptographic Libraries

Purpose-built or forked cryptographic implementations.

| Repository | Language | Description |
|------------|----------|-------------|
| [qp-rusty-crystals](https://github.com/Quantus-Network/qp-rusty-crystals) · [DeepWiki](https://deepwiki.com/Quantus-Network/qp-rusty-crystals) | Rust | ML-DSA-87 (Dilithium) implementation. Pure-Rust, no-std, constant-time. Includes HD-Lattice wallet derivation. **Audited by Neodyme.** |
| [qp-poseidon](https://github.com/Quantus-Network/qp-poseidon) · [DeepWiki](https://deepwiki.com/Quantus-Network/qp-poseidon) | Rust | Poseidon2 hash function. Used for block headers, storage hashing, QPoW mining, and ZK circuits. |
| [qp-poseidon-constants](https://github.com/Quantus-Network/qp-poseidon-constants) · [DeepWiki](https://deepwiki.com/Quantus-Network/qp-poseidon-constants) | Rust | Precomputed Poseidon2 constants for the Goldilocks field. |
| [qp-plonky2](https://github.com/Quantus-Network/qp-plonky2) · [DeepWiki](https://deepwiki.com/Quantus-Network/qp-plonky2) | Rust | Quantus fork of Polygon Zero's Plonky2 proof system. STARK-based, no trusted setup. |
| [qp-human-checkphrase](https://github.com/Quantus-Network/qp-human-checkphrase) · [DeepWiki](https://deepwiki.com/Quantus-Network/qp-human-checkphrase) | Python | Human-readable BIP-39 address checksums ("check-phrases"). |

## Post-Quantum Networking

Forked networking libraries with classical crypto replaced by PQC primitives.

| Repository | Language | Description |
|------------|----------|-------------|
| [qp-libp2p-identity](https://github.com/Quantus-Network/qp-libp2p-identity) · [DeepWiki](https://deepwiki.com/Quantus-Network/qp-libp2p-identity) | Rust | PQ fork of rust-libp2p-identity. Dilithium-based peer identity. |
| [qp-libp2p-noise](https://github.com/Quantus-Network/qp-libp2p-noise) · [DeepWiki](https://deepwiki.com/Quantus-Network/qp-libp2p-noise) | Rust | PQ fork of rust-libp2p-noise. ML-KEM-768 + ML-DSA-87 for P2P channel encryption. |
| [sc-network-pqc](https://github.com/Quantus-Network/sc-network-pqc) · [DeepWiki](https://deepwiki.com/Quantus-Network/sc-network-pqc) | Rust | PQ fork of Substrate's sc-network. |

## Client Applications

User-facing software for interacting with the network.

| Repository | Language | Description |
|------------|----------|-------------|
| [quantus-cli](https://github.com/Quantus-Network/quantus-cli) · [DeepWiki](https://deepwiki.com/Quantus-Network/quantus-cli) | Rust | Command-line client for Quantus Network. |
| [quantus-apps](https://github.com/Quantus-Network/quantus-apps) · [DeepWiki](https://deepwiki.com/Quantus-Network/quantus-apps) | Dart | Mobile and desktop wallet application (Flutter). |
| [quantus-miner](https://github.com/Quantus-Network/quantus-miner) · [DeepWiki](https://deepwiki.com/Quantus-Network/quantus-miner) | Rust | External mining software (CPU/GPU). |
| [miner-tauri-gui](https://github.com/Quantus-Network/miner-tauri-gui) · [DeepWiki](https://deepwiki.com/Quantus-Network/miner-tauri-gui) | Rust | Desktop mining GUI built with Tauri. |
| [quantus_ur](https://github.com/Quantus-Network/quantus_ur) · [DeepWiki](https://deepwiki.com/Quantus-Network/quantus_ur) | Rust | UR QR code implementation for hardware wallet communication. |

## Infrastructure

Operations, monitoring, and data indexing.

| Repository | Language | Description |
|------------|----------|-------------|
| [explorer](https://github.com/Quantus-Network/explorer) · [DeepWiki](https://deepwiki.com/Quantus-Network/explorer) | TypeScript | Custom block explorer built on Subsquid. |
| [monitoring](https://github.com/Quantus-Network/monitoring) · [DeepWiki](https://deepwiki.com/Quantus-Network/monitoring) | Shell | Network monitoring scripts and configurations. |
| [chain-telemetry](https://github.com/Quantus-Network/chain-telemetry) · [DeepWiki](https://deepwiki.com/Quantus-Network/chain-telemetry) | Rust | Telemetry service for chain metrics. |
| [n8n-workflows](https://github.com/Quantus-Network/n8n-workflows) · [DeepWiki](https://deepwiki.com/Quantus-Network/n8n-workflows) | -- | n8n automation workflows. |

## NEAR Integration

Cross-chain bridge infrastructure using NEAR's chain abstraction.

| Repository | Language | Description |
|------------|----------|-------------|
| [near-mpc](https://github.com/Quantus-Network/near-mpc) · [DeepWiki](https://deepwiki.com/Quantus-Network/near-mpc) | Rust | MPC node for secure multi-party threshold signature generation. **Under audit by Hashcloak.** |
| [nearcore](https://github.com/Quantus-Network/nearcore) · [DeepWiki](https://deepwiki.com/Quantus-Network/nearcore) | Rust | Fork of NEAR Protocol reference client. |

## SDK and API Clients

Libraries for building on Quantus.

| Repository | Language | Description |
|------------|----------|-------------|
| [quantus-api-client](https://github.com/Quantus-Network/quantus-api-client) · [DeepWiki](https://deepwiki.com/Quantus-Network/quantus-api-client) | Rust | Substrate API client over WebSockets. |
| [polkadart](https://github.com/Quantus-Network/polkadart) · [DeepWiki](https://deepwiki.com/Quantus-Network/polkadart) | Dart | Fork of Polkadart -- Dart/Flutter SDK for Polkadot-compatible chains. |
| [polkadot-js-api](https://github.com/Quantus-Network/polkadot-js-api) · [DeepWiki](https://deepwiki.com/Quantus-Network/polkadot-js-api) | TypeScript | Fork of Polkadot JS API. |

## State and Storage

ZK-compatible state management.

| Repository | Language | Description |
|------------|----------|-------------|
| [zk-trie](https://github.com/Quantus-Network/zk-trie) · [DeepWiki](https://deepwiki.com/Quantus-Network/zk-trie) | Rust | ZK-friendly Substrate Patricia Merkle Trie. Uses Poseidon hashing for ZK-compatible state proofs. |
| [zk-state-machine](https://github.com/Quantus-Network/zk-state-machine) · [DeepWiki](https://deepwiki.com/Quantus-Network/zk-state-machine) | Rust | Fork of Substrate sp-state-machine adapted for zk-trie. |

## Data Indexing

Forked indexing frameworks for the block explorer.

| Repository | Language | Description |
|------------|----------|-------------|
| [squid-sdk](https://github.com/Quantus-Network/squid-sdk) · [DeepWiki](https://deepwiki.com/Quantus-Network/squid-sdk) | TypeScript | Fork of Subsquid SDK. Powers the explorer. |
| [subql](https://github.com/Quantus-Network/subql) · [DeepWiki](https://deepwiki.com/Quantus-Network/subql) | TypeScript | Fork of SubQuery indexing framework. |

## Content and Public-Facing

Websites, documentation, and research.

| Repository | Language | Description |
|------------|----------|-------------|
| [website](https://github.com/Quantus-Network/website) · [DeepWiki](https://deepwiki.com/Quantus-Network/website) | MDX | quantus.com main website. |
| [whitepaper](https://github.com/Quantus-Network/whitepaper) · [DeepWiki](https://deepwiki.com/Quantus-Network/whitepaper) | -- | White paper versioning. |
| [qsafe.af](https://github.com/Quantus-Network/qsafe.af) · [DeepWiki](https://deepwiki.com/Quantus-Network/qsafe.af) | TypeScript | qsafe.af -- quantum safety awareness site. |
| [report-card](https://github.com/Quantus-Network/report-card) · [DeepWiki](https://deepwiki.com/Quantus-Network/report-card) | Astro | Quantum Security Report Card -- rates other chains' quantum readiness. |
| [privacy-score](https://github.com/Quantus-Network/privacy-score) · [DeepWiki](https://deepwiki.com/Quantus-Network/privacy-score) | TypeScript | Privacy scoring tool for blockchain protocols. |

## Governance and Standards

| Repository | Language | Description |
|------------|----------|-------------|
| [improvement-proposals](https://github.com/Quantus-Network/improvement-proposals) · [DeepWiki](https://deepwiki.com/Quantus-Network/improvement-proposals) | -- | Quantus Improvement Proposals (QIPs). |
| [slips](https://github.com/Quantus-Network/slips) · [DeepWiki](https://deepwiki.com/Quantus-Network/slips) | Markdown | Fork of SatoshiLabs Improvement Proposals. |

## Hardware Integration

| Repository | Language | Description |
|------------|----------|-------------|
| [keystone3-firmware](https://github.com/Quantus-Network/keystone3-firmware) · [DeepWiki](https://deepwiki.com/Quantus-Network/keystone3-firmware) | C | Fork of Keystone hardware wallet firmware with PQ support. |

## Internal Tools

| Repository | Language | Description |
|------------|----------|-------------|
| [task-master](https://github.com/Quantus-Network/task-master) · [DeepWiki](https://deepwiki.com/Quantus-Network/task-master) | Rust | Task management system built on reversible transactions. |
| [task-master-admin](https://github.com/Quantus-Network/task-master-admin) · [DeepWiki](https://deepwiki.com/Quantus-Network/task-master-admin) | TypeScript | Admin panel for task-master. |
| [rusx](https://github.com/Quantus-Network/rusx) · [DeepWiki](https://deepwiki.com/Quantus-Network/rusx) | Rust | Rust SDK for the X / Twitter API v2. |
| [hash-comparison](https://github.com/Quantus-Network/hash-comparison) · [DeepWiki](https://deepwiki.com/Quantus-Network/hash-comparison) | Rust | Benchmarks comparing hash function performance. |
| [logs](https://github.com/Quantus-Network/logs) · [DeepWiki](https://deepwiki.com/Quantus-Network/logs) | -- | Operational logs. |

## Release Management Test Repos

Used for testing CI/CD and release workflows. Not production code.

`chain-rm` | `chain-ru-test` | `chain-update2512` | `quantus-miner-rm` | `qp-poseidon-rm` | `poseidon-resonance-rm` | `plonky2-rm` | `plonky2-rm2` | `quantus-cli-rm`
