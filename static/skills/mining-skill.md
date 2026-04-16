---
name: mining
description: Set up and manage Quantus mining nodes. Walks through Docker or binary setup, key generation, wormhole address creation, and node launch. Opinionated toward Docker on a VPS but adapts to local Mac/Linux. Use when user says "set up mining," "start mining," "deploy a miner," "mine Quantus," or similar.
user_invocable: true
---

# Quantus Mining Setup

Interactive mining setup for the Quantus Planck testnet. Handles key generation, wormhole address creation, and node launch.

## Source of Truth

Mining commands and flags were validated against quantus-node v0.6.1 and quantus-miner v3.0.0 on 2026-04-16. The upstream MINING.md (https://github.com/Quantus-Network/chain/blob/main/MINING.md) may lag behind actual releases — this skill reflects tested behavior.

**Critical architecture detail:** The node is the QUIC server (listens on port 9833 via `--miner-listen-port`). The miner is the QUIC client (connects via `--node-addr`). The node must start first, then the miner connects to it.

## Step 0: Determine Environment

Use AskUserQuestion to ask:

**"Where are you setting up mining?"**
- **VPS / remote server (Docker)** -- Recommended. Runs in a Docker container on a remote Linux server.
- **Local Mac / Linux (Docker)** -- Run Docker locally on your own machine.
- **Local Mac / Linux (binary)** -- Download and run the binary directly, no Docker.

Store the answer as `DEPLOY_MODE` for the rest of the flow.

## Step 1: Configure Mining Resources

Detect the machine's CPU cores:
```bash
nproc 2>/dev/null || sysctl -n hw.ncpu
```

Then ask the user using AskUserQuestion:

**"Do you have a GPU you want to use for mining? GPU mining is strongly recommended -- it produces significantly higher hash rates than CPU."**
- **Yes** -- I have a GPU available for mining
- **No / not sure** -- CPU only

Then show the user what was detected and ask directly:

> "Your machine has [N] CPU cores. How many CPU workers and GPU devices do you want to dedicate to mining?"

Suggest defaults based on `DEPLOY_MODE`:
- **VPS (dedicated):** All GPU devices, 0 CPU workers if GPU is available (lets the CPU handle the node). If CPU-only, use all cores.
- **Local machine:** GPU recommended with 0 CPU workers. If CPU-only, leave 2 cores free for the OS (e.g., 6 workers on an 8-core machine).

Store as `CPU_WORKERS` and `GPU_DEVICES` for the miner command.

---

## Docker Flow (VPS or Local Docker)

Run each step using the Bash tool. Before each command that changes system state, show the user what you're about to run and ask for confirmation.

### 1. Check Docker is installed

```bash
docker --version
```

If Docker is not installed, tell the user to install it first:
- Linux: `curl -fsSL https://get.docker.com | sh && sudo usermod -aG docker $USER` (then re-login)
- macOS: Install Docker Desktop from https://www.docker.com/products/docker-desktop/

### 2. Pull the latest image

```bash
docker pull ghcr.io/quantus-network/quantus-node:latest
```

### 3. Create data directory

```bash
mkdir -p ./quantus_node_data
```

On Linux, also run:
```bash
chmod 755 quantus_node_data
```

### 4. Generate node identity (P2P key)

Detect if Apple Silicon and add `--platform linux/amd64` if needed:

```bash
# Check architecture
uname -m
```

Then run:
```bash
docker run --rm [PLATFORM_FLAG] \
  -v "$(pwd)/quantus_node_data":/var/lib/quantus_data \
  ghcr.io/quantus-network/quantus-node:latest \
  key generate-node-key --file /var/lib/quantus_data/node_key.p2p
```

Where `[PLATFORM_FLAG]` is `--platform linux/amd64` on Apple Silicon (arm64), or omitted on x86_64/amd64.

### 5. Generate wormhole address

```bash
docker run --rm [PLATFORM_FLAG] \
  ghcr.io/quantus-network/quantus-node:latest \
  key quantus --scheme wormhole
```

**Important:** Display the output clearly and tell the user to save **all three values**:
- **Address** — their wormhole address where rewards are sent
- **inner_hash** — the preimage needed to start mining (used for `--rewards-inner-hash`)
- **Secret** — the private key that proves ownership of the wormhole address. Without this, mined rewards cannot be claimed or transferred.

All three must be backed up securely. Suggest storing in a `.env` file with `chmod 600` permissions.

**Existing wallet holders:** You can derive a wormhole keypair from an existing mnemonic or seed instead of generating a fresh one:
```bash
./quantus-node key quantus --scheme wormhole --words "your 24 word mnemonic"
./quantus-node key quantus --scheme wormhole --seed <64-char-hex-private-key>
```
This produces a wormhole address linked to your existing key material. If you generate without `--words` or `--seed`, you get a brand new keypair unrelated to any existing wallet.

### 6. Start the node

Ask the user for:
- Their `inner_hash` from step 5
- A node name (optional, defaults to auto-generated)

```bash
docker run -d \
  --name quantus-node \
  --restart unless-stopped \
  -v "$(pwd)/quantus_node_data":/var/lib/quantus \
  -p 30333:30333 \
  -p 9944:9944 \
  -p 9833:9833 \
  [PLATFORM_FLAG] \
  ghcr.io/quantus-network/quantus-node:latest \
  --validator \
  --base-path /var/lib/quantus \
  --chain planck \
  --node-key-file /var/lib/quantus/node_key.p2p \
  --rewards-inner-hash <INNER_HASH> \
  --miner-listen-port 9833 \
  --name <NODE_NAME>
```

### 7. Start the external miner

The miner is a separate process that connects to the node via QUIC. The node must already be running and listening on port 9833 before the miner can connect.

Download the miner binary from https://github.com/Quantus-Network/quantus-miner/releases/latest (or build from source).

For macOS: `xattr -d com.apple.quarantine quantus-miner && chmod u+x quantus-miner`

Wait for the node logs to show `⛏️ Miner server listening on port 9833`, then start the miner with the resource settings from Step 1:

```bash
./quantus-miner serve \
  --node-addr 127.0.0.1:9833 \
  --cpu-workers <CPU_WORKERS> \
  --gpu-devices <GPU_DEVICES>
```

**Note on Docker networking:** If the node runs in Docker and the miner runs on the host, `127.0.0.1:9833` works because we exposed `-p 9833:9833`. If both run in Docker, use a shared Docker network and the container name instead.

Where `<CPU_WORKERS>` and `<GPU_DEVICES>` are the values calculated in Step 1.

Examples:
- Full GPU: `--cpu-workers 0 --gpu-devices 1` (or however many GPUs detected)
- Half CPU, no GPU: `--cpu-workers 4 --gpu-devices 0` (on an 8-core machine)
- Light: `--cpu-workers 2 --gpu-devices 0`

**Important:** The miner runs in the foreground. On a VPS, consider running it in a tmux/screen session or with nohup:
```bash
nohup ./quantus-miner serve --node-addr 127.0.0.1:9833 --cpu-workers <N> --gpu-devices <N> > miner.log 2>&1 &
```

### 8. Verify it's running

```bash
docker logs --tail 20 quantus-node
```

Look for lines like `Imported #XXXX` indicating sync progress. Tell the user:
- Mining starts automatically once the node finishes syncing and the miner connects
- They can check telemetry at https://telemetry.quantus.cat/
- View node logs anytime with `docker logs -f quantus-node`
- View miner logs with `tail -f miner.log` (if using nohup) or in the miner terminal

---

## Binary Flow (Local Mac / Linux)

### 1. Detect platform and download binary

```bash
uname -s  # Darwin = macOS, Linux = Linux
uname -m  # arm64 = Apple Silicon, x86_64 = Intel/AMD
```

Direct the user to download the correct binary from https://github.com/Quantus-Network/chain/releases/latest

### 2. Download the miner binary

Also download from https://github.com/Quantus-Network/quantus-miner/releases/latest

### 3. Fix permissions (macOS only)

```bash
xattr -d com.apple.quarantine quantus-node
xattr -d com.apple.quarantine quantus-miner
chmod u+x quantus-node quantus-miner
```

### 4. Generate node identity

```bash
./quantus-node key generate-node-key --file ~/.quantus/node_key.p2p
```

### 5. Generate wormhole address

```bash
./quantus-node key quantus --scheme wormhole
```

Same instructions as Docker step 5 — save **all three values**: Address, inner_hash, and Secret. Can also use `--words` or `--seed` to derive from existing key material.

### 6. Start the node

```bash
RUST_LOG=info ./quantus-node \
    --validator \
    --chain planck \
    --node-key-file ~/.quantus/node_key.p2p \
    --rewards-inner-hash <INNER_HASH> \
    --miner-listen-port 9833 \
    --sync full \
    --name <NODE_NAME>
```

Wait for `⛏️ Miner server listening on port 9833` in the logs before starting the miner.

### 7. Start the external miner

In a **separate terminal**, start the miner with the resource settings from Step 1:

```bash
RUST_LOG=info ./quantus-miner serve \
  --node-addr 127.0.0.1:9833 \
  --cpu-workers <CPU_WORKERS> \
  --gpu-devices <GPU_DEVICES>
```

GPU mining is strongly recommended — GPU produces ~500-1000 MH/s vs ~15 MH/s per CPU thread.

### 8. Verify

Look for `Imported #XXXX` lines in the node output. The miner terminal should show hash rate and job completions. Mining begins after the node finishes syncing and the miner connects. The miner will show `⛏️ Connected to node at 127.0.0.1:9833` when the QUIC connection is established.

---

## Post-Setup: Management Commands

After setup is complete, provide these reference commands:

**Docker:**
```bash
docker logs -f quantus-node     # Live logs
docker stop quantus-node        # Stop
docker start quantus-node       # Start
docker stop quantus-node && docker rm quantus-node  # Remove

# Update to latest
docker pull ghcr.io/quantus-network/quantus-node:latest
# Then re-run the docker run command (data is preserved)
```

**Binary:**
```bash
# Check latest block
curl -s -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"chain_getBlock","params":[]}' \
  http://localhost:9944

# Check node health
curl -s -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"system_health","params":[]}' \
  http://localhost:9944
```

**Check balance (no CLI needed — via RPC):**

```bash
# Replace ACCT with your wormhole address hex (without 0x prefix, from .env WORMHOLE_ADDRESS_HEX)
ACCT="your_wormhole_address_hex_here"

BLAKE2_128=$(python3 -c "
import hashlib
data = bytes.fromhex('$ACCT')
print(hashlib.blake2b(data, digest_size=16).hexdigest())
")

STORAGE_KEY="0x26aa394eea5630e07c48ae0c9558cef7b99d880ec681799c0cf30e8886371da9${BLAKE2_128}${ACCT}"

RESULT=$(curl -s -H "Content-Type: application/json" -d "{
  \"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"state_getStorage\",\"params\":[\"$STORAGE_KEY\"]
}" http://127.0.0.1:9944)

python3 -c "
import json
data = bytes.fromhex(json.loads('$RESULT'.replace(\"'\", \"\"))['result'][2:])
free = int.from_bytes(data[16:32], 'little')
print(f'Balance: {free / 1e12:.6f} PLK')
"
```

**Check balance + blocks mined (via Subsquid indexer):**

```bash
curl -s -X POST https://subsquid.quantus.com/blue/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "{ minerRewards(where: {miner: {id_eq: \"YOUR_WORMHOLE_SS58_ADDRESS\"}}, orderBy: timestamp_DESC, limit: 500) { reward block { height } timestamp } }"
  }' | python3 -c "
import json, sys
rewards = json.load(sys.stdin)['data']['minerRewards']
total = sum(int(r['reward']) for r in rewards)
print(f'Blocks mined: {len(rewards)}')
print(f'Total rewards: {total / 1e12:.6f} PLK')
if rewards:
    print(f'Latest block: {rewards[0][\"block\"][\"height\"]}')
    print(f'Avg per block: {total / 1e12 / len(rewards):.6f} PLK')
"
```

**Check on explorer:** https://explorer.quantus.com/ — search by wormhole SS58 address.

**Check balance (with quantus-cli):**
```bash
quantus balance --address <YOUR_WORMHOLE_ADDRESS>
```

**Claiming mining rewards:**

Mining rewards auto-deposit to your wormhole address. The miner's share per block on Planck is ~0.39 PLK (~0.555 PLK total split with treasury). To spend rewards, you need to withdraw from the wormhole via ZK proof.

**Option A — `collect-rewards` (recommended, requires quantus-cli with PR #90 merged):**
```bash
quantus wormhole collect-rewards --wallet <wallet-name>
quantus wormhole collect-rewards --wallet <wallet-name> --dry-run  # preview first
```
This one command handles the entire flow: query pending transfers, filter spent nullifiers, generate ZK proofs, aggregate, and submit withdrawal. Check PR status: https://github.com/Quantus-Network/quantus-cli/pull/90

**Option B — Manual wormhole prove flow (current stable CLI):**
```bash
# 1. Generate ZK proof for withdrawal
quantus wormhole prove \
  --secret <your-wormhole-secret> \
  --amount <amount-in-planck> \
  --exit-account <your-regular-wallet-address> \
  --block <block-hash-of-transfer> \
  --transfer-count <from-event> \
  --leaf-index <from-event> \
  --funding-account <minting-account-address> \
  --output proof.hex

# 2. Aggregate proofs (if multiple)
quantus wormhole aggregate --proofs proof1.hex --output aggregated.hex

# 3. Submit proof on-chain to release funds
quantus wormhole verify-aggregated --proof aggregated.hex

# 4. Send from your regular wallet
quantus send --from <wallet-name> --to <recipient> --amount 100
```

**Note:** The manual flow requires knowing the exact block hash, transfer count, and leaf index from on-chain events. Use Option A when available.

---

## Troubleshooting

If the user reports issues, check:

| Problem | Fix |
|---------|-----|
| Docker not found | Install Docker (see step 1) |
| Port 30333 in use | `--port 30334` or stop conflicting process |
| Not mining | Verify `--validator` flag and `--rewards-inner-hash` |
| macOS blocks binary | `xattr -d com.apple.quarantine quantus-node` |
| Database corruption | `docker exec quantus-node quantus-node purge-chain --chain planck` or `./quantus-node purge-chain --chain planck` |
| Can't find rewards | Check wormhole Address from key generation or node startup logs |
| Miner can't connect | Ensure node is started first and shows "Miner server listening on port 9833" |
| Machine sluggish | Reduce CPU workers: `--cpu-workers 0 --gpu-devices 1` (GPU alone is ~50x faster per worker) |
| "Long-range attack" error on first block | Benign race condition during sync — resolves on next block |
| Miner fails immediately | `--node-addr` is required in v3.0.0. Make sure node is running first. |
| GPU "search exhausted" but no blocks mined | Normal — difficulty increased or other miners found the solution first. The miner is working correctly, just losing the race. |

## Key Facts

- Chain: Planck testnet
- Block time: ~6 seconds
- Consensus: QPoW (Poseidon2)
- Tokens have no monetary value (testnet)
- Network may be reset periodically
- Telemetry: https://telemetry.quantus.cat/
- Explorer: https://explorer.quantus.com/
- Subsquid indexer: https://subsquid.quantus.com/blue/graphql
- Token: PLK (12 decimals)
- Block reward: ~0.555 PLK total (~0.39 PLK miner share, rest to treasury)
- Telegram: https://t.me/quantusnetwork
- Node binary: https://github.com/Quantus-Network/chain/releases/latest
- Miner binary: https://github.com/Quantus-Network/quantus-miner/releases/latest
- CLI: https://github.com/Quantus-Network/quantus-cli (v1.2.1)
- Last validated: 2026-04-16 with quantus-node v0.6.1, quantus-miner v3.0.0
