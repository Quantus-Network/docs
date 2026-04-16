---
sidebar_position: 1
title: Mining and Running a Node
---

# Mining and Running a Node

This guide covers connecting to the Quantus Planck testnet and mining. Works on macOS and Linux (including WSL2 on Windows). Choose binary or Docker installation below.

Use the buttons in the top-right corner of this page to copy the full guide as Markdown, or to copy an AI mining skill you can give to an agent like Claude Code to walk you through setup interactively.

## System Requirements

| Requirement | Minimum | Recommended |
|------------|---------|-------------|
| CPU | 2+ cores | 4+ cores |
| RAM | 4 GB | 8 GB+ |
| Storage | 100 GB | 500 GB+ SSD |
| Network | 3+ Mbps stable | 10+ Mbps broadband |
| OS | Linux (Ubuntu 20.04+), macOS 10.15+, or Windows WSL2 | Linux recommended |

## Wormhole Address System

Mining rewards are sent to a **wormhole address** derived from a 32-byte preimage you generate during setup. This is privacy-preserving by default -- all miners use wormhole addresses.

**Existing wallet holders:** You can derive a wormhole keypair from an existing mnemonic or seed instead of generating a fresh one:

```bash
./quantus-node key quantus --scheme wormhole --words "your 24 word mnemonic"
./quantus-node key quantus --scheme wormhole --seed <64-char-hex-private-key>
```

If you run the command without `--words` or `--seed`, a brand new keypair is generated unrelated to any existing wallet.

During setup you will run `key quantus --scheme wormhole`, which outputs three values:

| Value | What it is | What to do |
|-------|-----------|------------|
| **Address** | Your wormhole address (where rewards are sent) | Save for monitoring |
| **inner_hash** | 32-byte preimage | Pass to the node via `--rewards-inner-hash` |
| **Secret** | Private key proving ownership | Back up securely -- loss means loss of rewards |

The node derives your wormhole address from the `inner_hash` and logs it on startup.

:::info Built-in vs External Miner
Running the node with `--validator` alone enables a basic **CPU-only** miner built into the node. For GPU mining and higher hash rates, use the **external miner** (separate `quantus-miner` binary). GPU mining is strongly recommended -- it produces ~500-1000 MH/s vs ~15 MH/s per CPU worker.
:::

---

## Option A: Binary Installation (Mac / Linux)

### 1. Download the Binary

Get the latest `quantus-node` binary for your platform from [GitHub Releases](https://github.com/Quantus-Network/chain/releases/latest). Place it in a working directory.

**macOS only -- fix Gatekeeper permissions:**

```bash
xattr -d com.apple.quarantine quantus-node
chmod u+x quantus-node
```

### 2. Generate Node Identity

```bash
./quantus-node key generate-node-key --file ~/.quantus/node_key.p2p
```

### 3. Generate Wormhole Address

```bash
./quantus-node key quantus --scheme wormhole
```

This outputs three values: **Address**, **inner_hash**, and **Secret**. Save all three securely. See the [Wormhole Address System](#wormhole-address-system) table above for what each value does.

### 4. Start the Node

```bash
./quantus-node \
    --validator \
    --chain planck \
    --node-key-file ~/.quantus/node_key.p2p \
    --rewards-inner-hash <YOUR_INNER_HASH> \
    --miner-listen-port 9833 \
    --sync full \
    --name MYNAME
```

Replace `<YOUR_INNER_HASH>` with the `inner_hash` from step 3, and `MYNAME` with your preferred node name. The `--miner-listen-port` flag opens a QUIC server for the external miner to connect to.

The node will sync with the network. With `--validator` alone it runs a basic built-in CPU miner. For GPU mining, continue to step 5.

### 5. Start the External Miner (Recommended)

Download the miner binary from [Miner Releases](https://github.com/Quantus-Network/quantus-miner/releases/latest).

**macOS only:** `xattr -d com.apple.quarantine quantus-miner && chmod u+x quantus-miner`

Wait for the node logs to show the miner server is listening, then in a **separate terminal**:

```bash
RUST_LOG=info ./quantus-miner serve \
    --node-addr 127.0.0.1:9833 \
    --gpu-devices 1 \
    --cpu-workers 0
```

| Miner Flag | Default | Description |
|-----------|---------|-------------|
| `--node-addr` | Required | Node's QUIC miner port |
| `--gpu-devices N` | 0 | Number of GPUs to use |
| `--cpu-workers N` | Auto (half of cores) | CPU mining threads (0 to disable) |

For desktop machines, `--gpu-devices 1 --cpu-workers 0` gives the best balance of hash rate and system usability.

---

## Option B: Docker Installation (Mac / Linux)

Works on any platform with Docker 20.10+. Recommended for VPS deployments.

### 1. Prepare Data Directory

```bash
mkdir -p ./quantus_node_data
```

On Linux, ensure Docker can access it:

```bash
chmod 755 quantus_node_data
```

### 2. Generate Node Identity

```bash
docker run --rm \
  -v "$(pwd)/quantus_node_data":/var/lib/quantus_data \
  ghcr.io/quantus-network/quantus-node:latest \
  key generate-node-key --file /var/lib/quantus_data/node_key.p2p
```

:::note Apple Silicon
Add `--platform linux/amd64` after `docker run --rm` on M1/M2/M3/M4 Macs. This applies to all Docker commands in this guide.
:::

### 3. Generate Wormhole Address

```bash
docker run --rm \
  ghcr.io/quantus-network/quantus-node:latest \
  key quantus --scheme wormhole
```

Save all three values (Address, inner_hash, Secret) securely. See the [Wormhole Address System](#wormhole-address-system) table above.

### 4. Run the Node

```bash
docker run -d \
  --name quantus-node \
  --restart unless-stopped \
  -v "$(pwd)/quantus_node_data":/var/lib/quantus \
  -p 30333:30333 \
  -p 9944:9944 \
  -p 9833:9833 \
  ghcr.io/quantus-network/quantus-node:latest \
  --validator \
  --base-path /var/lib/quantus \
  --chain planck \
  --node-key-file /var/lib/quantus/node_key.p2p \
  --rewards-inner-hash <YOUR_INNER_HASH> \
  --miner-listen-port 9833
```

For GPU mining, also start the external miner on the host after the node is running (see [External Miner Setup](#external-miner-setup) below). Port 9833 is exposed so the miner can connect from the host.

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

---

## External Miner Setup

For GPU mining and higher hash rates, run the external miner alongside your node. The node acts as a QUIC server on port 9833, and the miner connects as a client.

**Startup order matters:** the node must be running and listening before the miner can connect.

### 1. Get the Miner

Download the latest miner binary from [Miner Releases](https://github.com/Quantus-Network/quantus-miner/releases/latest), or build from source:

```bash
git clone https://github.com/Quantus-Network/quantus-miner
cd quantus-miner
cargo build --release
```

**macOS only:** run `xattr -d com.apple.quarantine quantus-miner && chmod u+x quantus-miner` on downloaded binaries.

### 2. Start the Node

Start the node with `--miner-listen-port` to open the QUIC server:

```bash
RUST_LOG=info ./quantus-node \
    --validator \
    --chain planck \
    --node-key-file ~/.quantus/node_key.p2p \
    --rewards-inner-hash <YOUR_INNER_HASH> \
    --miner-listen-port 9833
```

### 3. Start the Miner

Once the node logs show the miner server is listening, start the miner in a separate terminal:

```bash
RUST_LOG=info ./quantus-miner serve \
    --node-addr 127.0.0.1:9833 \
    --gpu-devices 1 \
    --cpu-workers 0
```

| Miner Flag | Default | Description |
|-----------|---------|-------------|
| `--node-addr` | Required | Address of node's QUIC miner port |
| `--gpu-devices N` | 0 | Number of GPUs to use |
| `--cpu-workers N` | Auto (half of cores) | CPU mining threads (0 to disable) |

Multiple miners can connect to the same node simultaneously. The node broadcasts jobs to all connected miners, and the first valid result wins.

---

## Running a Non-Mining Node

To sync and serve RPC queries without mining, omit `--validator` and the rewards flag:

```bash
./quantus-node \
    --chain planck \
    --node-key-file ~/.quantus/node_key.p2p \
    --sync full
```

---

## Monitoring

- **Telemetry dashboard:** [telemetry.quantus.cat](https://telemetry.quantus.cat/) -- find your node by name
- **Prometheus metrics:** `http://localhost:9615/metrics`
- **RPC endpoint:** `http://localhost:9944`

Your wormhole address is in the `Address` field from key generation, or in your node's startup logs.

:::note Checking Rewards
Balance-checking tooling for wormhole addresses is still in development. Watch the [Quantus GitHub](https://github.com/Quantus-Network) for updates.
:::

### Logs and Diagnostics

**Debug logging:**

```bash
RUST_LOG=debug,sc_consensus_pow=trace ./quantus-node [options]
```

**Inspect your node's P2P identity:**

```bash
./quantus-node key inspect-node-key --file ~/.quantus/node_key.p2p
```

**Query network state via RPC:**

```bash
# Node health
curl -s -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"system_health","params":[]}' \
  http://localhost:9944

# Network peers and state
curl -s -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"system_networkState","params":[]}' \
  http://localhost:9944

# Latest block
curl -s -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"chain_getBlock","params":[]}' \
  http://localhost:9944
```

---

## Mining Economics

### Rewards

All mining rewards are sent to your wormhole address automatically. The reward per block is determined by smooth exponential decay -- there are no abrupt halvings like Bitcoin.

| Component | Description |
|-----------|-------------|
| Block reward | ~0.555 PLK total per block (Planck testnet) |
| Miner share | ~0.39 PLK (~70% of block reward) |
| Treasury share | Remainder goes to the network treasury |
| Transaction fees | Miner tip for standard transfers; volume fee (partially burned) for wormhole transactions |

### Expected Performance

Mining performance depends on:

- **Hardware:** GPU mining produces ~500-1000 MH/s vs ~15 MH/s per CPU thread
- **Network latency:** Lower latency to peers means faster block propagation
- **Sync status:** Mining only starts after the node finishes syncing
- **Competition:** More miners on the network means lower individual block frequency

---

## Security Best Practices

### Key Management

- **Back up all three wormhole values** (Address, inner_hash, Secret) -- loss of the Secret means loss of rewards
- **Store keys securely** -- use encrypted storage or a password manager for the Secret and inner_hash
- **Back up your node identity** (`node_key.p2p`) separately

### Node Security

- **Firewall:** Only expose port 30333 (P2P). Keep 9833 (miner), 9944 (RPC), and 9615 (metrics) on localhost unless you have a specific reason to expose them
- **Updates:** Check [GitHub Releases](https://github.com/Quantus-Network/chain/releases/latest) for new versions regularly
- **Monitoring:** Watch for unusual peer counts, sync stalls, or dropped miner connections

### Testnet Disclaimer

Planck is testnet software for testing purposes only. Tokens have no monetary value. The network may be reset periodically, and breaking changes are expected between releases.

---

## Configuration Reference

| Parameter | Description | Default |
|-----------|-------------|---------|
| `--validator` | Enable mining | Required for mining |
| `--chain` | Chain specification | `planck` |
| `--node-key-file` | P2P identity file | Required |
| `--rewards-inner-hash` | Wormhole preimage from key generation | Required for mining |
| `--miner-listen-port` | Port for external miner QUIC connections | None (uses built-in CPU miner) |
| `--name` | Publicly visible node name | Auto-generated |
| `--port` | P2P networking port | 30333 |
| `--rpc-port` | JSON-RPC port | 9944 |
| `--prometheus-port` | Metrics port | 9615 |
| `--base-path` | Data directory | `~/.local/share/quantus-node` |
| `--max-blocks-per-request` | Sync batch size | 64 |

## Network Ports

| Port | Protocol | Purpose | Expose? |
|------|----------|---------|---------|
| 30333 | TCP | P2P networking | Yes (required) |
| 9833 | QUIC | External miner API (local) | No (localhost only) |
| 9944 | TCP | JSON-RPC | Only if needed |
| 9615 | TCP | Prometheus metrics | Only for monitoring |

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Port already in use | Use `--port 30334 --rpc-port 9945` |
| Database corruption | Run `quantus-node purge-chain --chain planck` |
| Mining not working | Verify `--validator` flag is present and `--rewards-inner-hash` is correct |
| macOS blocks binary | Run `xattr -d com.apple.quarantine <filename>` and `chmod u+x <filename>` |
| Connection issues | Check firewall allows port 30333 |
| Can't find rewards | Check the `Address` field from wormhole key generation, or node startup logs |
| Invalid preimage | Use the exact `inner_hash` value from `key quantus --scheme wormhole` |
| Miner can't connect | Ensure the node is running first and shows "Miner server listening on port 9833" in logs |
| Machine sluggish while mining | Reduce CPU workers: use `--cpu-workers 0 --gpu-devices 1` (GPU alone is ~50x faster per thread) |

### Getting Help

- **GitHub Issues:** [Report bugs](https://github.com/Quantus-Network/chain/issues)
- **Telegram:** [Quantus community](https://t.me/quantusnetwork)
- **Documentation:** [Chain repo wiki](https://github.com/Quantus-Network/chain/wiki)

## Testnet Information

| Property | Value |
|----------|-------|
| Chain | Planck testnet |
| Consensus | QPoW (Poseidon2 PoW) |
| Block Time | ~6 seconds target |
| Tokens | No monetary value (testnet) |
| Telemetry | [telemetry.quantus.cat](https://telemetry.quantus.cat/) |
| Community | [Telegram](https://t.me/quantusnetwork) |
| Explorer | [explorer.quantus.com](https://explorer.quantus.com/) |

## Next Steps

1. **Monitor your node** on the [telemetry dashboard](https://telemetry.quantus.cat/) -- find it by name
2. **Join the community** on [Telegram](https://t.me/quantusnetwork) for support and updates
3. **Check the explorer** at [explorer.quantus.com](https://explorer.quantus.com/) to look up your wormhole address
4. **Report issues** on [GitHub](https://github.com/Quantus-Network/chain/issues) if you hit bugs
