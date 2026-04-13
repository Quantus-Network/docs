---
sidebar_position: 3
title: Security & Audits
---

# Security and Audits

Quantus has engaged multiple independent security firms to audit critical components of the protocol. This page tracks audit status and links to published reports.

## Completed Audits

| Auditor | Scope | Status | Report |
|---------|-------|--------|--------|
| **Eiger** | Hash algorithm (Poseidon2) and consensus (QPoW) | Completed | [Link pending] |
| **Neodyme** | ML-DSA-87 / Dilithium signature implementation (qp-rusty-crystals) | Completed | [Link pending] |

## In-Progress Audits

| Auditor | Scope | Status |
|---------|-------|--------|
| **Eiger** | ZK circuits (qp-zk-circuits) -- wormhole circuit, prover, verifier, aggregator | In progress |
| **Hashcloak** | Threshold signatures (near-mpc) -- MPC node for NEAR chain abstraction | In progress |

## Security Architecture

Quantus's security model is layered across multiple boundaries:

### Cryptographic Layer
- **Transaction signatures:** ML-DSA-87 (NIST Level 5), audited by Neodyme
- **P2P encryption:** ML-KEM-768 + ML-DSA-87 via forked libp2p
- **Block hashing:** Poseidon2, audited by Eiger
- **ZK proofs:** Plonky2 STARKs (no trusted setup), audit in progress

### Consensus Layer
- **QPoW mining:** Double Poseidon2 hashing, audited by Eiger
- **Chain selection:** Heaviest-chain (cumulative work), not longest-chain
- **Finalization:** Deterministic at 179 blocks behind best

### Application Layer
- **Replay protection:** 11-stage transaction extension pipeline (CheckNonce, CheckEra, CheckGenesis, etc.)
- **High-security accounts:** Mandatory delay periods with guardian cancellation
- **Wormhole nullifiers:** Prevent double-spending of ZK proof-based transactions
- **Forkless upgrades:** Governance can patch vulnerabilities without hard forks

## Responsible Disclosure

Security issues should be reported to the Quantus team via:
- **GitHub Issues:** [Quantus-Network/chain](https://github.com/Quantus-Network/chain/issues) (for non-sensitive issues)
- **Direct contact:** For critical vulnerabilities, reach out via [Telegram](https://t.me/quantusnetwork) or team contacts

## Research

- [Messari Research Report](https://messari.io/report/quantus-network-quantum-defense)
- [research.quantus.com](https://research.quantus.com) (academic content in progress)
