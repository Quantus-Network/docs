---
sidebar_position: 1
title: Mining and Running a Node
---

# Mining and Running a Node

This guide covers everything you need to connect to the Quantus Network and start mining. The node connects you to the network, and the miner performs the work to secure it and earn you rewards.

## System Requirements

| Requirement | Minimum | Recommended |
|------------|---------|-------------|
| CPU | 2+ cores | 4+ cores |
| RAM | 4 GB | 8 GB+ |
| Storage | 100 GB | 500 GB+ SSD |
| Network | Stable internet | 10+ Mbps broadband |
| OS | Linux (Ubuntu 20.04+), macOS 10.15+, or Windows WSL2 | Linux recommended |

## Prerequisites

1. Download the Quantus mobile wallet from [linktr.ee/quantusnetwork](https://linktr.ee/quantusnetwork)
2. Create a wallet address to receive testnet tokens
3. Note your wallet address -- you will need it for the `--rewards-address` parameter

:::info Testnet Upgrades
If the testnet has upgraded, you may need to perform wallet migration. Your balance may show "0" temporarily, but previously mined tokens will be credited.
:::

## Step 1: Create a Working Directory

```bash
mkdir quantus
cd quantus
```

All subsequent commands run from this directory.

## Step 2: Download Node and Miner

**Quantus Node:**
- Download the latest release for your OS from [GitHub Releases](https://github.com/Quantus-Network/chain/releases/latest)
- Extract and place `quantus-node` in your `quantus` directory

**Quantus Miner:**
- Download the matching version from [Miner Releases](https://github.com/Quantus-Network/quantus-miner/releases/latest)
- Place the miner binary (e.g., `quantus-miner-macos-aarch64`) in your `quantus` directory

Verify both files are present:

```bash
ls
# Should show: quantus-node  quantus-miner-macos-aarch64 (or your platform variant)
```

### macOS: Fix Gatekeeper Permissions

macOS blocks downloaded binaries by default. Run these commands to allow execution:

```bash
# For the node
xattr -d com.apple.quarantine quantus-node
chmod u+x quantus-node

# For the miner (use your actual filename)
xattr -d com.apple.quarantine quantus-miner-macos-aarch64
chmod u+x quantus-miner-macos-aarch64
```

## Step 3: Start the Miner

Open a **new terminal window**, navigate to your `quantus` directory, and start the miner:

```bash
./quantus-miner-macos-aarch64 serve --cpu-workers 4 --gpu-devices 1
```

| Option | Description |
|--------|-------------|
| `--cpu-workers N` | Number of CPU threads to use (one per core recommended) |
| `--gpu-devices N` | Number of GPUs to use (0 for CPU-only mining) |

Keep this terminal running.

## Step 4: Generate Node Identity

Back in your original terminal:

```bash
./quantus-node key generate-node-key --file node-key
```

This creates a `node-key` file for your P2P identity on the network.

## Step 5: Start the Node

Replace `MYNAME` with your publicly visible node name, and `<YOUR REWARDS ADDRESS>` with your wallet address from the mobile app:

```bash
./quantus-node \
    --max-blocks-per-request 64 \
    --validator \
    --chain dirac \
    --sync full \
    --node-key-file node-key \
    --external-miner-url http://localhost:9833 \
    --rewards-address <YOUR REWARDS ADDRESS> \
    --name MYNAME \
    --base-path chain_data_dir
```

The node will sync with the network and begin mining once synchronization is complete.

## Monitoring

- **Telemetry dashboard:** [telemetry.quantus.cat](https://telemetry.quantus.cat/) -- find your node by name
- **Prometheus metrics:** `http://localhost:9616/metrics` (block height, peer count, difficulty)
- **Video walkthrough:** [Loom video guide](https://www.loom.com/share/f39d2cbaf0e646048ac6c81d415d389e)

### Check Logs

Look for lines like:
```
Imported #12345 (0xabc...)
```

This means your node is syncing and importing blocks.

## Alternative: Docker Setup

If you prefer Docker over downloading binaries:

```bash
# Prepare data directory
mkdir -p ./quantus_node_data

# Generate node identity
docker run --rm \
  -v "$(pwd)/quantus_node_data":/var/lib/quantus_data \
  ghcr.io/quantus-network/quantus-node:latest \
  key generate-node-key --file /var/lib/quantus_data/node_key.p2p

# Run the node
docker run -d \
  --name quantus-node \
  --restart unless-stopped \
  -v "$(pwd)/quantus_node_data":/var/lib/quantus \
  -p 30333:30333 \
  -p 9944:9944 \
  ghcr.io/quantus-network/quantus-node:latest \
  --validator \
  --base-path /var/lib/quantus \
  --chain dirac \
  --node-key-file /var/lib/quantus/node_key.p2p \
  --rewards-address <YOUR REWARDS ADDRESS>
```

:::note Apple Silicon
Add `--platform linux/amd64` to all Docker commands on M1/M2/M3/M4 Macs.
:::

### Docker Management

```bash
# View logs
docker logs -f quantus-node

# Stop / start
docker stop quantus-node
docker start quantus-node

# Update to latest version
docker stop quantus-node && docker rm quantus-node
docker pull ghcr.io/quantus-network/quantus-node:latest
# Re-run the docker run command above (data is preserved)
```

## Alternative: Build from Source

```bash
# Install Rust nightly
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup toolchain install nightly
rustup default nightly

# Clone and build the node
git clone https://github.com/Quantus-Network/chain.git
cd chain
cargo build --release
# Binary: ./target/release/quantus-node

# Clone and build the miner
git clone https://github.com/Quantus-Network/quantus-miner
cd quantus-miner
cargo build --release
# Binary: ./target/release/quantus-miner
```

## Running a Non-Mining Node

To run a node that syncs and serves RPC queries without mining, omit `--validator` and the miner-related flags:

```bash
./quantus-node \
    --chain dirac \
    --node-key-file node-key \
    --sync full \
    --base-path chain_data_dir
```

### RPC Endpoints

The JSON-RPC API is available on port 9944:

```bash
# Get latest block
curl -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"chain_getBlock","params":[]}' \
  http://localhost:9944

# Get network state
curl -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"system_networkState","params":[]}' \
  http://localhost:9944
```

### Debug Logging

```bash
# General debug
RUST_LOG=debug ./quantus-node [options]

# Consensus-specific debug
RUST_LOG=info,sc_consensus_pow=debug ./quantus-node [options]
```

## Configuration Reference

| Parameter | Description | Default |
|-----------|-------------|---------|
| `--validator` | Enable mining | Required for mining |
| `--chain` | Chain specification | `dirac` (testnet) |
| `--node-key-file` | P2P identity file | Required |
| `--rewards-address` | Wallet address for mining rewards | Required for mining |
| `--external-miner-url` | External miner API endpoint | `http://localhost:9833` |
| `--name` | Publicly visible node name | None |
| `--port` | P2P networking port | 30333 |
| `--rpc-port` | JSON-RPC port | 9944 |
| `--prometheus-port` | Metrics port | 9616 |
| `--base-path` | Data directory | `~/.local/share/quantus-node` |
| `--max-blocks-per-request` | Sync batch size | 64 |
| `--cpu-workers` | Miner: CPU threads | All cores |
| `--gpu-devices` | Miner: GPU count | 0 |

## Network Ports

| Port | Protocol | Purpose | Expose? |
|------|----------|---------|---------|
| 30333 | TCP | P2P networking | Yes (required) |
| 9833 | TCP | Miner API (local) | No (localhost only) |
| 9944 | TCP | JSON-RPC | Only if needed |
| 9616 | TCP | Prometheus metrics | Only for monitoring |

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Port already in use | Use `--port 30334 --rpc-port 9945` |
| Database corruption | Run `quantus-node purge-chain --chain dirac` |
| Mining not working | Verify `--validator` flag is present and miner process is running |
| macOS blocks binary | Run `xattr -d com.apple.quarantine <filename>` and `chmod u+x <filename>` |
| Connection issues | Check firewall allows port 30333 |

## Testnet Information

| Property | Value |
|----------|-------|
| Chain | Dirac Testnet |
| Consensus | QPoW (Poseidon2 PoW) |
| Block Time | ~12 seconds target |
| Tokens | No monetary value (testnet) |
| Telemetry | [telemetry.quantus.cat](https://telemetry.quantus.cat/) |
| Community | [Telegram](https://t.me/quantusnetwork) |
