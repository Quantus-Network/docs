---
sidebar_position: 7
title: External Miner Protocol
---

# External Miner Protocol Specification

Technical specification for the QUIC-based protocol between the Quantus node and external miner services. This is developer documentation for building custom miner implementations. For setup instructions, see the [Mining Guide](/guides/mining).

## Overview

The node delegates the mining task (finding a valid nonce) to external miner services over persistent QUIC connections. The node provides the necessary parameters (header hash, difficulty threshold) and each miner independently searches for a valid nonce using the PoW rules defined in the `qpow-math` crate (double Poseidon2 hash). Miners push results back when found.

### Why QUIC

| Property | Benefit |
|----------|---------|
| Low latency | Results are pushed immediately when found (no polling) |
| Connection resilience | Built-in connection migration and recovery |
| Multiplexed streams | Multiple operations on a single connection |
| Built-in TLS | Encrypted by default |

## Architecture

```
                           ┌─────────────────────────────────┐
                           │            Node                 │
                           │   (QUIC Server on port 9833)    │
                           │                                 │
┌──────────┐               │  Broadcasts: NewJob             │
│  Miner 1 │ ──connect───> │  Receives: JobResult            │
└──────────┘               │                                 │
                           │  Supports multiple miners       │
┌──────────┐               │  First valid result wins        │
│  Miner 2 │ ──connect───> │                                 │
└──────────┘               └─────────────────────────────────┘

┌──────────┐
│  Miner 3 │ ──connect───>
└──────────┘
```

- **Node** acts as the QUIC server, listening on port 9833 (configured via `--miner-listen-port`)
- **Miners** act as QUIC clients, connecting to the node via `--node-addr`
- Single bidirectional stream per miner connection
- Connection persists across multiple mining jobs
- Multiple miners can connect simultaneously

### Multi-Miner Operation

When multiple miners are connected:

1. Node broadcasts the same `NewJob` to all connected miners
2. Each miner independently selects a random starting nonce
3. First miner to find a valid solution sends `JobResult`
4. Node uses the first valid result and ignores subsequent results for the same job
5. New job broadcast implicitly cancels work on all miners

## Message Types

The protocol uses three message types:

| Direction | Message | Description |
|-----------|---------|-------------|
| Miner -> Node | `Ready` | Sent immediately after connecting to establish the stream |
| Node -> Miner | `NewJob` | Submit a mining job (implicitly cancels any previous job) |
| Miner -> Node | `JobResult` | Mining result (completed, failed, or cancelled) |

### Wire Format

Messages are length-prefixed JSON:

```
┌─────────────────┬─────────────────────────────────┐
│ Length (4 bytes) │ JSON payload (MinerMessage)      │
│ big-endian u32   │                                  │
└─────────────────┴─────────────────────────────────┘
```

Maximum message size: 16 MB.

## Data Types

See the `quantus-miner-api` crate for the canonical Rust definitions.

### MinerMessage (Enum)

```rust
pub enum MinerMessage {
    Ready,                      // Miner -> Node: establish stream
    NewJob(MiningRequest),      // Node -> Miner: submit job
    JobResult(MiningResult),    // Miner -> Node: return result
}
```

### MiningRequest

| Field | Type | Description |
|-------|------|-------------|
| `job_id` | String | Unique identifier (UUID) |
| `mining_hash` | String | Header hash (64 hex chars, no `0x` prefix) |
| `distance_threshold` | String | Difficulty target (U512 as decimal string) |

Nonce range is not specified -- each miner independently selects a random starting point from the 512-bit nonce space.

### MiningResult

| Field | Type | Description |
|-------|------|-------------|
| `status` | ApiResponseStatus | Result status |
| `job_id` | String | Job identifier (must match the request) |
| `nonce` | Option\<String\> | Winning nonce (U512 hex, no `0x` prefix) |
| `work` | Option\<String\> | Winning nonce as bytes (128 hex chars) |
| `hash_count` | u64 | Number of nonces checked |
| `elapsed_time` | f64 | Time spent mining (seconds) |
| `miner_id` | Option\<u64\> | Miner ID (set by node, not miner) |

### ApiResponseStatus

| Value | Description |
|-------|-------------|
| `completed` | Valid nonce found |
| `failed` | Nonce range exhausted without finding solution |
| `cancelled` | Job was cancelled (new job received) |
| `running` | Job still in progress (not typically sent) |

## Protocol Flow

### Normal Mining

```
Miner                                        Node
  |                                            |
  |---- QUIC Connect ---------------------------->
  |<--- Connection Established -------------------|
  |                                            |
  |---- Ready ---------------------------------->  (establish stream)
  |                                            |
  |<--- NewJob { job_id: "abc", ... } ------------|
  |                                            |
  |     (picks random nonce, starts mining)    |
  |                                            |
  |---- JobResult { job_id: "abc", ... } -------->  (found solution)
  |                                            |
  |     (node submits block, gets new work)    |
  |                                            |
  |<--- NewJob { job_id: "def", ... } ------------|
```

### Implicit Job Cancellation

When a new block arrives before the miner finds a solution, the node sends a new `NewJob`. The miner automatically cancels the previous job:

```
Miner                                        Node
  |                                            |
  |<--- NewJob { job_id: "abc", ... } ------------|
  |                                            |
  |     (mining "abc")                         |
  |                                            |
  |     (new block arrives at node)            |
  |                                            |
  |<--- NewJob { job_id: "def", ... } ------------|
  |                                            |
  |     (cancels "abc", starts "def")          |
  |                                            |
  |---- JobResult { job_id: "def", ... } -------->
```

### Late Connect

When a miner connects while a job is already active, it immediately receives the current job:

```
Miner (new)                                  Node
  |                                            | (already mining job "abc")
  |---- QUIC Connect ---------------------------->
  |<--- Connection Established -------------------|
  |                                            |
  |---- Ready ---------------------------------->  (establish stream)
  |                                            |
  |<--- NewJob { job_id: "abc", ... } ------------|  (current job sent immediately)
  |                                            |
  |     (joins mining effort)                  |
```

### Stale Result Handling

If a result arrives for an old job, the node discards it:

```
Miner                                        Node
  |                                            |
  |<--- NewJob { job_id: "abc", ... } ------------|
  |                                            |
  |<--- NewJob { job_id: "def", ... } ------------|  (almost simultaneous)
  |                                            |
  |---- JobResult { job_id: "abc", ... } -------->  (stale, node ignores)
  |                                            |
  |---- JobResult { job_id: "def", ... } -------->  (current, node uses)
```

## Configuration

### Node

```bash
# Listen for external miner connections on port 9833
quantus-node --validator --chain planck --miner-listen-port 9833
```

### Miner

```bash
# Connect to node
quantus-miner serve --node-addr 127.0.0.1:9833
```

| Miner Flag | Default | Description |
|-----------|---------|-------------|
| `--node-addr` | Required | Address of node's QUIC miner port |
| `--gpu-devices N` | 0 | Number of GPUs to use |
| `--cpu-workers N` | Auto (half of cores) | CPU mining threads (0 to disable) |

## TLS Configuration

The node generates a self-signed TLS certificate at startup. The miner skips certificate verification by default. For production deployments, consider:

- **Certificate pinning** -- Configure the miner to accept only specific certificate fingerprints
- **Proper CA** -- Use certificates signed by a trusted CA
- **Network isolation** -- Run node and miner on a private network

## Error Handling

### Connection Loss

The miner automatically reconnects with exponential backoff:
- Initial delay: 1 second
- Maximum delay: 30 seconds

The node continues operating with remaining connected miners.

### Validation Errors

If the miner receives an invalid `MiningRequest`, it sends a `JobResult` with status `failed`.

## Implementation Notes

- All hex values are sent **without** the `0x` prefix
- The miner implements validation logic from `qpow_math::is_valid_nonce`
- The node uses the `work` field from `MiningResult` to construct `QPoWSeal`
- ALPN protocol identifier: `quantus-miner`
- Each miner generates a random nonce starting point using cryptographically secure randomness
- With a 512-bit nonce space, collision between miners is statistically impossible

## Source Code

| Component | Repository |
|-----------|-----------|
| Miner API types | [quantus-miner-api](https://github.com/Quantus-Network/quantus-miner) (api crate) |
| Miner implementation | [quantus-miner](https://github.com/Quantus-Network/quantus-miner) |
| Node consensus engine | [chain/client/consensus/qpow](https://github.com/Quantus-Network/chain/tree/main/client/consensus/qpow) |
| PoW math | [chain/qpow-math](https://github.com/Quantus-Network/chain/tree/main/qpow-math) |
