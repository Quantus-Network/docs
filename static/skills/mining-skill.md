---
name: mining
description: Set up and manage a Quantus mining node on macOS or Linux. Walks the user through binary download, node identity, wormhole address generation, node + external miner launch, monitoring, and claiming rewards. Use when user says "set up mining," "start mining," "mine Quantus," "run a Quantus node," or similar.
user_invocable: true
---

# Quantus Mining Setup

Interactive mining setup for the Quantus Planck testnet on macOS or Linux (including WSL2 on Windows). Handles node identity, wormhole address generation, node launch, external miner launch, and reward claiming.

This skill mirrors the public mining guide at https://docs.quantus.com/guides/mining but is optimized for an AI agent walking a user through setup step by step.

## Source of Truth

Mining commands and flags are aligned with the official chain wiki (https://github.com/Quantus-Network/chain/wiki). Node binary releases: https://github.com/Quantus-Network/chain/releases/latest. Miner binary releases: https://github.com/Quantus-Network/quantus-miner/releases/latest. CLI releases: https://github.com/Quantus-Network/quantus-cli/releases/latest.

**Critical architecture:** The node is the QUIC server (listens on port 9833 via `--miner-listen-port`). The external miner is the QUIC client (connects via `--node-addr`). Start the node first, wait for it to log that the miner server is listening, then start the miner.

## Step 1: Prerequisites Check

Before anything else, confirm the user has:

1. **A Quantus wallet** -- downloaded from https://linktr.ee/quantusnetwork. Used to hold funds and eventually claim mining rewards.
2. **A 24-word mnemonic / seed phrase** -- generated in the wallet app (or the CLI). This is the source of the wormhole address that receives rewards.

Use AskUserQuestion to confirm both. If either is missing, pause the flow and direct the user to the wallet download first.

## Step 2: Explain Wormhole Addresses

Before running any commands, explain briefly:

> Mining rewards on Quantus are sent to a **wormhole address**, derived from a 32-byte preimage called the `inner_hash`. Wormhole addresses are privacy-preserving by default. You can later claim rewards out of the wormhole to either another wormhole address or a regular (dilithium) wallet address.

The `key quantus --scheme wormhole` command outputs three values the user must save:

| Value | Purpose | Handling |
|-------|---------|----------|
| **Address** | Wormhole address where rewards accumulate | Save for monitoring / explorer lookups |
| **inner_hash** | 32-byte preimage | Pass to node via `--rewards-inner-hash` |
| **Secret** | Private key proving ownership | Back up securely -- loss means loss of rewards |

## Step 3: Configure Mining Resources

Per repo preference: **always recommend GPU mining** and **always ask about resource allocation before starting the miner**. GPU produces ~500-1000 MH/s vs ~15 MH/s per CPU worker.

Detect CPU cores:
```bash
nproc 2>/dev/null || sysctl -n hw.ncpu
```

Ask via AskUserQuestion:

**"Do you have a GPU available for mining? GPU mining is strongly recommended."**
- **Yes** -- I have a GPU I can use
- **No / not sure** -- CPU only

Then ask directly: **"Your machine has [N] CPU cores. How many CPU workers and GPU devices should we dedicate to mining?"**

Suggested defaults:
- **GPU available:** `--gpu-devices 1 --cpu-workers 0` (let CPU run the node).
- **CPU only:** leave 2 cores free for the OS (e.g., 6 workers on 8-core).

Store answers as `CPU_WORKERS` and `GPU_DEVICES` for the miner command.

## Step 4: Detect Platform

```bash
uname -s   # Darwin = macOS, Linux = Linux
uname -m   # arm64 / aarch64 = Apple Silicon, x86_64 = Intel/AMD
```

Note for the user: on macOS, `aarch64-apple` binaries are for Apple Silicon (M1+); `x86-apple` is for Intel Macs.

## Step 5: Download the Node Binary

Direct the user to download the correct `quantus-node` archive for their platform from:
https://github.com/Quantus-Network/chain/releases/latest

Have them place the archive in a clean working directory (e.g., `~/quantus-mining`).

Extract (on macOS, double-click also works):
```bash
cd ~/quantus-mining
tar -xzf quantus-node-*.tar.gz 2>/dev/null || unzip quantus-node-*.zip
```

**macOS only -- fix Gatekeeper quarantine:**
```bash
xattr -d com.apple.quarantine quantus-node 2>/dev/null || true
chmod u+x quantus-node
```

## Step 6: Generate Node Identity

```bash
./quantus-node key generate-node-key --file node_key.p2p
```

This creates a `node_key.p2p` file used for the node's P2P identity. Keep it in the working directory.

## Step 7: Generate Inner Hash (Wormhole Address)

Two options -- ask the user which they want via AskUserQuestion:

**Option A -- Derive from existing wallet mnemonic (recommended if they already have a Quantus wallet):**
```bash
./quantus-node key quantus --scheme wormhole --words "24 word mnemonic here in quotes"
```

**Option B -- Generate a fresh keypair unrelated to any existing wallet:**
```bash
./quantus-node key quantus --scheme wormhole
```

In both cases, the command outputs the Address, inner_hash, and Secret. Display the output to the user and remind them:

> **Save all three values securely.** The `Secret` cannot be recovered. Loss of the Secret means loss of all rewards sitting at the wormhole address.

Store `INNER_HASH` for the next step. Also suggest the user save all three to a `.env` file with `chmod 600`.

## Step 8: Start the Node

Ask the user for a node name (any string -- shows up on telemetry).

```bash
./quantus-node \
  --name <NODE_NAME> \
  --validator \
  --miner-listen-port 9833 \
  --chain planck \
  --node-key-file node_key.p2p \
  --rewards-inner-hash <INNER_HASH> \
  --max-blocks-per-request 64 \
  --sync full
```

Replace `<NODE_NAME>` and `<INNER_HASH>`. The node runs in the foreground; suggest running in a tmux/screen session, or with `nohup ... > node.log 2>&1 &` if the user wants it backgrounded.

Wait for the node logs to show that the miner server is listening on port 9833 before proceeding.

## Step 9: Download and Start the External Miner

In a **separate terminal**, download the miner binary from:
https://github.com/Quantus-Network/quantus-miner/releases/latest

**macOS only:**
```bash
xattr -d com.apple.quarantine quantus-miner-macos-aarch64 2>/dev/null || true
chmod u+x quantus-miner-macos-aarch64
```

(Replace the filename with the one matching the user's platform.)

Start the miner with the resource settings from Step 3:
```bash
./quantus-miner-macos-aarch64 serve \
  --cpu-workers <CPU_WORKERS> \
  --gpu-devices <GPU_DEVICES> \
  --node-addr 127.0.0.1:9833
```

The miner will connect to the node over QUIC and begin mining once the node finishes syncing.

## Step 10: Verify Mining Is Working

Tell the user to look for these signs:
- **Node log:** `Imported #XXXX` lines indicate sync progress.
- **Miner log:** hash rate and job completions; `Connected to node at 127.0.0.1:9833` confirms the QUIC link.
- **Telemetry:** the node name appears at https://telemetry.quantus.cat/.

Mining begins automatically once the node is synced and the miner is connected.

---

## Monitoring

- **Telemetry dashboard:** https://telemetry.quantus.cat/ -- find the node by name.
- **Prometheus metrics:** `http://localhost:9615/metrics`.
- **RPC endpoint:** `http://localhost:9944`.
- **Explorer:** https://explorer.quantus.com/ -- search by wormhole SS58 address.
- **Real-time node log:**
  ```bash
  tail -f ~/.local/share/quantus-node/chains/planck/network/quantus-node.log
  ```
- **Inspect P2P identity:**
  ```bash
  ./quantus-node key inspect-node-key --file node_key.p2p
  ```

## Claiming Rewards

Mining rewards auto-deposit to the wormhole address. To spend them, claim via the `quantus-cli`.

### 1. Download quantus-cli

Grab the latest archive into the same working directory:
https://github.com/Quantus-Network/quantus-cli/releases/latest

### 2. Extract, make executable, clear macOS quarantine

```bash
tar -xzf quantus-*-quantus-cli.tar.gz || tar -xzf quantus-cli-*.tar.gz
mv */quantus ./quantus 2>/dev/null || true
chmod +x quantus
xattr -d com.apple.quarantine quantus 2>/dev/null || true
```

### 3. Import the secret phrase into a wallet named `mining`

Use the **same 24 words** that produced the wormhole address in Step 7.

```bash
./quantus wallet import --name mining --mnemonic "24 word mnemonic here in quotes"
```

### 4. Collect mined tokens via public Planck RPC

```bash
./quantus \
  --node-url wss://a1-planck.quantus.cat \
  --verbose --wait-for-transaction \
  wormhole collect-rewards --wallet mining
```

Suggest `--dry-run` first to preview:
```bash
./quantus \
  --node-url wss://a1-planck.quantus.cat \
  wormhole collect-rewards --wallet mining --dry-run
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| macOS blocks binary | `xattr -d com.apple.quarantine <binary> && chmod u+x <binary>` |
| Port 30333 in use | Add `--port 30334` (or stop the conflicting process) |
| Not mining | Confirm `--validator` and `--rewards-inner-hash` are set; confirm miner connected |
| Miner can't connect | Start the node first; wait for "Miner server listening on port 9833" before launching the miner |
| Miner fails immediately | `--node-addr` is required (QUIC protocol). Ensure node is already running. |
| Database corruption | `./quantus-node purge-chain --chain planck` |
| Can't find rewards | Check wormhole Address from Step 7 output or node startup logs; look up on explorer |
| Machine sluggish | Reduce CPU workers; prefer GPU: `--cpu-workers 0 --gpu-devices 1` |
| "Long-range attack" on first block | Benign race during sync; resolves on next block |
| GPU "search exhausted" but no blocks mined | Normal -- difficulty rose or another miner won the race. Miner is working correctly. |

## Management Commands

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

**Balance via CLI (after `wallet import`):**
```bash
./quantus balance --address <WORMHOLE_ADDRESS>
```

## Security Best Practices

- **Back up the 24-word seed phrase and Secret** -- offline, ideally in two physical locations. Loss is irrecoverable.
- **Firewall:** expose only port 30333 (P2P). Keep 9833 (miner), 9944 (RPC), and 9615 (metrics) on localhost.
- **Updates:** watch https://github.com/Quantus-Network/chain/releases/latest for new versions; Planck is active testnet and may reset or have breaking changes.
- **Testnet disclaimer:** PLK tokens have no monetary value. The network may be reset periodically.

## Key Facts

- Chain: Planck testnet
- Block time: ~6 seconds
- Consensus: QPoW (Poseidon2)
- Miner protocol: QUIC (node is server on port 9833; miner is client via `--node-addr`)
- Token: PLK (12 decimals)
- Block reward: ~0.555 PLK total (~0.39 PLK miner share, rest to treasury)
- Telemetry: https://telemetry.quantus.cat/
- Explorer: https://explorer.quantus.com/
- Node binary: https://github.com/Quantus-Network/chain/releases/latest
- Miner binary: https://github.com/Quantus-Network/quantus-miner/releases/latest
- CLI: https://github.com/Quantus-Network/quantus-cli/releases/latest
- Telegram: https://t.me/quantusnetwork
- GitHub Issues: https://github.com/Quantus-Network/chain/issues
