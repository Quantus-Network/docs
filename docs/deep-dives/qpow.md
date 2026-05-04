---
sidebar_position: 2
title: QPoW Consensus & Mining
---

# QPoW Consensus & Mining

Quantus uses a custom Proof-of-Work consensus mechanism called **QPoW (Quantum Proof-of-Work)**. It replaces SHA-256 with Poseidon2 hashing, so the mining algorithm and ZK proof system share the same hash function.

## Why Proof of Work?

Quantus is a store of value, not a smart contract platform. PoW provides:

- **Fair distribution:** Anyone can mine, no minimum stake required
- **Censorship resistance:** No validator set that can be coerced
- **No plutocracy:** Wealth doesn't compound into more consensus power
- **Proven security model:** 15+ years of battle-tested economics from Bitcoin

## How QPoW Works

The mining algorithm uses **double Poseidon2 hashing** instead of SHA-256:

```
nonce_hash = Poseidon2(Poseidon2(block_hash || nonce))
valid = nonce_hash < (U512::MAX / difficulty)
```

A miner finds a valid block by searching for a nonce where the double Poseidon2 hash is below the difficulty target.

### Why Poseidon2?

Poseidon2 was chosen for ZK circuit efficiency, **not** for quantum resistance (SHA-256 is already quantum-resistant enough). The benefit is that mining work can be efficiently verified inside ZK proofs, which enables future features like provable mining statistics and ZK-verified mining pools.

### Mining Flow

```mermaid
flowchart TD
    Miner["Miner<br/>(Local or External)"] --> BuildBlock["Build candidate block"]
    BuildBlock --> TryNonce["Try nonce batch<br/>(50K nonces/batch)"]
    TryNonce --> Hash["Double Poseidon2<br/>hash = P2(P2(block_hash || nonce))"]
    Hash --> Check{"hash < target?"}
    Check -->|No| TryNonce
    Check -->|Yes| Seal["Create seal with nonce"]
    Seal --> Import["Import block<br/>PowBlockImport verifies"]
    Import --> Broadcast["Broadcast to network"]
    Broadcast --> Difficulty["Difficulty adjusts<br/>on finalization"]
```

## Chain Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| Block Time | ~12 seconds target | Planck testnet |
| Max Reorg Depth | 180 blocks | `MaxReorgDepth` |
| Difficulty Adjustment | +/-10% per block | `DifficultyAdjustPercentClamp` |
| EMA Smoothing | alpha = 0.1 | `EmaAlpha = 100/1000` |
| Finalization | 179 blocks behind best | `MaxReorgDepth - 1` |
| Native Token | QUAN (12 decimals) | Max supply 21,000,000 |
| SS58 Prefix | 189 | Addresses start with `qz...` |

## Difficulty Adjustment

Difficulty adjusts on every finalized block using an exponential moving average (EMA):

1. Compute actual block time for the finalized block
2. Apply EMA smoothing: `ema = actual_time * alpha + prev_ema * (1 - alpha)`
3. Compare EMA to target block time
4. Adjust difficulty up or down, clamped to +/-10% per adjustment

This produces smoother difficulty curves than Bitcoin's 2016-block epoch adjustments, responding faster to hashrate changes while avoiding oscillation.

## Chain Selection: Heaviest Chain

Instead of "longest chain" (most blocks), Quantus uses **heaviest chain** (most cumulative work):

- Each block adds its difficulty to the chain's `TotalWork`
- Fork choice selects the chain with highest `TotalWork`
- This correctly weights high-difficulty blocks over many easy blocks

Finalization occurs automatically at `MaxReorgDepth - 1` blocks behind the best block (179 blocks), meaning blocks older than ~18 minutes are considered final.

## Mining Modes

### Built-in Mining (CPU Only)

The node binary includes a basic CPU-only miner for testing and small-scale mining:

```bash
./quantus-node \
    --validator \
    --chain planck \
    --node-key-file ~/.quantus/node_key.p2p \
    --rewards-inner-hash <YOUR_INNER_HASH>
```

Processes 50,000 nonces per batch. Built-in mining is limited to ~15 MH/s per CPU thread.

### External Mining (GPU Recommended)

For higher performance, a separate miner process offloads the PoW computation. The node acts as a QUIC server and the miner connects as a client:

```bash
# Start the node with the miner listen port open
RUST_LOG=info ./quantus-node \
    --validator \
    --chain planck \
    --node-key-file ~/.quantus/node_key.p2p \
    --rewards-inner-hash <YOUR_INNER_HASH> \
    --miner-listen-port 9833

# In a separate terminal, start the external miner
RUST_LOG=info ./quantus-miner serve \
    --node-addr 127.0.0.1:9833 \
    --gpu-devices 1 \
    --cpu-workers 0
```

GPU mining produces ~500-1000 MH/s vs ~15 MH/s per CPU thread. Multiple miners can connect to the same node simultaneously -- the node broadcasts jobs to all connected miners and the first valid result wins.

For the full QUIC protocol specification, see [External Miner Protocol](./miner-protocol).

**Source:** [quantus-miner](https://github.com/Quantus-Network/quantus-miner)

### GUI Miner

A desktop application built with Tauri wraps the miner CLI for non-technical users.

**Source:** [miner-tauri-gui](https://github.com/Quantus-Network/miner-tauri-gui)

## Mining Rewards

All mining rewards are sent to **wormhole addresses** derived from the miner's preimage. This is **not** optional. It is built into the protocol.

### Wormhole Address Derivation for Miners

1. Generate a wormhole key pair: `./quantus-node key quantus --scheme wormhole`
2. Save all three output values: **Address** (where rewards go), **inner_hash** (preimage for the node), and **Secret** (private key proving ownership)
3. The `inner_hash` is used as the `--rewards-inner-hash` parameter
4. The node derives the wormhole address on startup and logs it

Existing wallet holders can derive a wormhole keypair from an existing mnemonic via `--words "your 24 word mnemonic"` or from a seed via `--seed <64-char-hex>`.

This means mining rewards are automatically privacy-preserving. The miner's identity is not linked to their reward address on-chain.

### Emission Schedule

Quantus uses smooth exponential decay instead of Bitcoin's abrupt halvings:

```
Block Reward = (MaxSupply - CurrentSupply) / EmissionDivisor
```

- No halving cliffs that disrupt mining economics
- ~99% of supply emitted within ~40 years
- Miners receive 50% of total supply over time
- Company receives 15% via dev tax on block rewards (~5 years to fully vest)

### Fee Structure

| Transaction Type | Fee Model |
|-----------------|-----------|
| Standard transfer | Miner tip (priority fee) |
| Wormhole / High-Security | Volume fee split between miner and **burn** |

## Key Source Code

| Component | Repository | Path |
|-----------|-----------|------|
| QPoW math (nonce hash, validation) | [chain](https://github.com/Quantus-Network/chain) | `qpow-math/src/lib.rs` |
| Consensus engine | [chain](https://github.com/Quantus-Network/chain) | `client/consensus/qpow/` |
| QPoW pallet (difficulty, rewards) | [chain](https://github.com/Quantus-Network/chain) | `pallets/qpow/` |
| Mining rewards pallet | [chain](https://github.com/Quantus-Network/chain) | `pallets/mining-rewards/` |
| External miner | [quantus-miner](https://github.com/Quantus-Network/quantus-miner) | Root |
| Miner GUI | [miner-tauri-gui](https://github.com/Quantus-Network/miner-tauri-gui) | Root |
| Poseidon2 hash function | [qp-poseidon](https://github.com/Quantus-Network/qp-poseidon) | Root |
