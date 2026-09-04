---
name: mining
description: Set up and manage a Quantus mining node on macOS or Linux. Walks the user through binary download, node identity, wormhole address generation, node + external miner launch, and monitoring. Use when user says "set up mining," "start mining," "mine Quantus," "run a Quantus node," or similar.
user_invocable: true
---

# Quantus Mining Setup

Interactive mining setup for the Quantus Planck testnet on macOS or Linux (including WSL2 on Windows). Handles node identity, wormhole address generation, node launch, and external miner launch. Rewards are spendable directly from the wallet app (no claiming step).

This skill mirrors the public mining guide at https://docs.quantus.com/guides/mining but is optimized for an AI agent walking a user through setup step by step.

## Source of Truth

Mining commands and flags are aligned with chain MINING.md (https://github.com/Quantus-Network/chain/blob/main/MINING.md). Node binary releases: https://github.com/Quantus-Network/chain/releases/latest. Miner binary releases: https://github.com/Quantus-Network/quantus-miner/releases/latest.

**Critical architecture:** The node is the QUIC server (listens on port 9833 via `--miner-listen-port`). The external miner is the QUIC client (connects via `--node-addr`). Start the node first; wait for it to log that the miner server is listening before starting the miner. Node and miner versions must be a matching pair.

**Miner protocol -- probe the binaries you actually downloaded.** As of 2026-09-03, GitHub `releases/latest` are auth-era (node `v0.10.0`, miner `v4.0.2`); node `v0.9.0-endless-sky` / miner `v3.3.1` and earlier are pre-auth. Do **not** wait for `miner-auth-token` or pass `--auth-token-file` unless **both** binaries advertise those flags.

Capture `--help` exit status first. A non-zero exit is a broken, quarantined, or wrong-architecture binary -- **stop** and fix it. Do **not** treat a failed probe as pre-auth (`*_auth=no`). Do not pipe `--help` into `grep` until the command itself exits 0.

Run the snippet as a script (`bash probe-miner-protocol.sh`), not by pasting it into an interactive shell.

```bash
node_help="$(./quantus-node --help 2>&1)" && node_status=0 || node_status=$?
if [ "$node_status" -ne 0 ]; then
  echo "quantus-node --help failed (exit ${node_status}). STOP. Do not classify as pre-auth." >&2
  printf '%s\n' "$node_help" >&2
  exit 1
fi

miner_help="$(./quantus-miner serve --help 2>&1)" && miner_status=0 || miner_status=$?
if [ "$miner_status" -ne 0 ]; then
  echo "quantus-miner serve --help failed (exit ${miner_status}). STOP. Do not classify as pre-auth." >&2
  printf '%s\n' "$miner_help" >&2
  exit 1
fi

printf '%s' "$node_help" | grep -q -- miner-auth-token-file && node_auth=yes || node_auth=no
if printf '%s' "$miner_help" | grep -q -- auth-token-file \
  && printf '%s' "$miner_help" | grep -q -- tls-cert-sha256-file; then
  miner_auth=yes
else
  miner_auth=no
fi
echo "node_auth=${node_auth} miner_auth=${miner_auth}"
```

Replace `./quantus-node` / `./quantus-miner` with the actual downloaded filenames. `/usr/bin/false` (or any failed `--help`) must exit 1 here and must not print `node_auth=no`.

- **Both no, after successful `--help` (pre-auth pair):** wait only for "miner server listening"; start the miner with `--node-addr` only.
- **Both yes:** wait for `miner-auth-token` and `miner-tls-cert-sha256` under the chain directory, then pass `--auth-token-file` and `--tls-cert-sha256-file`. ALPN is `quantus-miner/2`.
- **Mixed:** stop. Pin a matching pair (`NODE_VERSION` / `MINER_VERSION` in `mining.conf`, then `setup --force`); do not mix independent `releases/latest` tags.

## Step 1: Prerequisites Check

Before anything else, confirm the user has:

1. **A Quantus wallet** -- downloaded from https://linktr.ee/quantusnetwork. Used to hold funds and spend mining rewards (the app supports wormhole balances directly).
2. **A 24-word mnemonic / seed phrase** -- generated in the wallet app (or the CLI). This is the source of the wormhole address that receives rewards.

Use AskUserQuestion to confirm both. If either is missing, pause the flow and direct the user to the wallet download first.

## Step 2: Explain Wormhole Addresses

Before running any commands, explain briefly:

> Mining rewards on Quantus are sent to a **wormhole address**, derived from a 32-byte preimage called the `inner_hash`. Wormhole addresses are privacy-preserving by default. Rewards accumulate at the wormhole address; the wallet app shows and spends them directly from the wormhole balance.

The `key quantus --scheme wormhole` command outputs three values the user must save:

| Value | Purpose | Handling |
|-------|---------|----------|
| **Address** | Wormhole address where rewards accumulate | Save for monitoring / explorer lookups |
| **inner_hash** | 32-byte preimage | Pass to node via `--rewards-inner-hash` |
| **Secret phrase** | Mnemonic proving ownership | Back up securely -- loss means loss of rewards |

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
./quantus-node key quantus --scheme wormhole --words
```
`--words` takes no argument: the command reads the 24-word phrase from stdin (interactive prompt without echo on a terminal). **Have the user type their mnemonic into the prompt themselves in their own terminal. Never ask the user to share the mnemonic with you, and never place it in a command line, chat, or file.**

**Option B -- Generate a fresh keypair unrelated to any existing wallet:**
```bash
./quantus-node key quantus --scheme wormhole
```

The two options produce different output:

- **Option A (supplied mnemonic):** outputs `Address` and `Inner Hash` only. The mnemonic is deliberately **not** echoed back -- the user's existing offline backup of their wallet phrase remains the only copy, which is correct.
- **Option B (fresh keypair):** additionally prints a new `Secret phrase`. Tell the user to write it down and store it in a secure offline backup (or password manager) immediately. **Never save the secret phrase to a file on disk, and never handle it yourself.** A lost secret phrase cannot be recovered -- losing it means losing all rewards at the wormhole address.

Store `INNER_HASH` for the next step. It is fine to persist the `Address` and `Inner Hash` in a `chmod 600` `.env` file -- they are not secrets in the way the phrase is (the inner hash is a commitment) -- but the secret phrase never goes in any file.

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

Wait for the node logs to show that the miner server is listening on port 9833 before proceeding. Default chain directory:

- Linux: `~/.local/share/quantus-node/chains/planck/`
- macOS: `~/Library/Application Support/quantus-node/chains/planck/`

Store as a quoted `CHAIN_DIR` (required on macOS — the path contains a space):

```bash
# Darwin
CHAIN_DIR="$HOME/Library/Application Support/quantus-node/chains/planck"
# Linux
# CHAIN_DIR="$HOME/.local/share/quantus-node/chains/planck"
```

If the protocol probe in Source of Truth was **both yes**, also wait until `miner-auth-token` and `miner-tls-cert-sha256` exist under `CHAIN_DIR`. The token itself is **not** logged -- read the file. **Never ask the user to paste the auth token into chat.** If the probe was **both no**, do not wait for those files; they will not be created.

## Step 9: Download and Start the External Miner

In a **separate terminal**, download a miner release that matches the node from:
https://github.com/Quantus-Network/quantus-miner/releases

**macOS only:**
```bash
xattr -d com.apple.quarantine quantus-miner-macos-aarch64 2>/dev/null || true
chmod u+x quantus-miner-macos-aarch64
```

(Replace the filename with the one matching the user's platform.)

Start the miner with the resource settings from Step 3. Always quote `"$CHAIN_DIR/..."` when using auth files.

**Pre-auth pair (current latest -- omit auth flags):**
```bash
./quantus-miner-macos-aarch64 serve \
  --cpu-workers <CPU_WORKERS> \
  --gpu-devices <GPU_DEVICES> \
  --node-addr 127.0.0.1:9833
```

**Auth pair (both `--help` probes yes):**
```bash
CHAIN_DIR="$HOME/Library/Application Support/quantus-node/chains/planck"
# Linux: CHAIN_DIR="$HOME/.local/share/quantus-node/chains/planck"

./quantus-miner-macos-aarch64 serve \
  --cpu-workers <CPU_WORKERS> \
  --gpu-devices <GPU_DEVICES> \
  --node-addr 127.0.0.1:9833 \
  --auth-token-file "$CHAIN_DIR/miner-auth-token" \
  --tls-cert-sha256-file "$CHAIN_DIR/miner-tls-cert-sha256"
```

Prefer file flags over `--auth-token` / `--tls-cert-sha256` so the secret is not in shell history. On an auth pair, a wrong token or TLS pin is a permanent error -- do not retry-loop; fix the paths. On a pre-auth pair, extra auth flags are unknown arguments and the miner will exit immediately.

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
  # Linux
  tail -f ~/.local/share/quantus-node/chains/planck/network/quantus-node.log
  # macOS
  tail -f ~/Library/Application\ Support/quantus-node/chains/planck/network/quantus-node.log
  ```
- **Inspect P2P identity:**
  ```bash
  ./quantus-node key inspect-node-key --file node_key.p2p
  ```

## Rewards

Mining rewards auto-deposit to the wormhole address. The Quantus wallet app supports wormhole addresses and encrypted accounts: if the user mined with the same seed phrase as their app wallet, rewards appear in the app automatically and are spendable directly from the wormhole balance. There is no separate claiming step -- do not walk the user through quantus-cli claiming; it is obsolete.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| macOS blocks binary | `xattr -d com.apple.quarantine <binary> && chmod u+x <binary>` |
| Port 30333 in use | Add `--port 30334` (or stop the conflicting process) |
| Not mining | Confirm `--validator` and `--rewards-inner-hash` are set; confirm miner connected |
| Miner can't connect | Start the node first; wait for "Miner server listening on port 9833" before launching the miner |
| Miner fails immediately | If the pair is pre-auth, drop `--auth-token-file` / `--tls-cert-sha256-file`. If it is an auth pair, both flags are required and both files must exist under `CHAIN_DIR`. A wrong token/pin or ALPN mismatch (`quantus-miner/2`) is permanent -- fix config, do not reconnect-loop. |
| "no application protocol" | Node/miner version mismatch (ALPN). Use matching releases. |
| Auth rejected | Token file does not match the node's `miner-auth-token`. Re-read the file; do not take the token from logs (it is never logged). |
| Database corruption | `./quantus-node purge-chain --chain planck` |
| Can't find rewards | Check wormhole Address from Step 7 output or node startup logs; look up on explorer |
| Machine sluggish | Reduce CPU workers; prefer GPU: `--cpu-workers 0 --gpu-devices 1` |
| "Long-range attack" on first block | Benign race during sync; resolves on next block |
| Sync stalls with `Verification failed` errors and 0 peers | Node version out of step with the network -- check https://github.com/Quantus-Network/chain/releases and community announcements for the version the network is running |
| Blocks "won" while node shows 0 peers / still syncing | Orphan blocks on an isolated fork; they earn nothing. Only mine once the node is at the chain tip |
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

## Security Best Practices

- **Back up the 24-word seed phrase and Secret** -- offline, ideally in two physical locations. Loss is irrecoverable.
- **Firewall:** expose only port 30333 (P2P). Keep 9833/UDP (miner), 9944 (RPC), and 9615 (metrics) on localhost. Miner auth + TLS pinning do **not** make 9833 safe to publish. For remote miners, use a VPN/private network.
- **Miner secrets:** treat `miner-auth-token` like a password. Never paste it into chat, command lines, or tickets.
- **Updates:** watch https://github.com/Quantus-Network/chain/releases/latest for new versions; Planck is active testnet and may reset or have breaking changes.
- **Testnet disclaimer:** PLK tokens have no monetary value. The network may be reset periodically.

## Key Facts

- Chain: Planck testnet
- Block time: ~6 seconds
- Consensus: QPoW (Poseidon2)
- Miner protocol: QUIC. Pre-auth latest releases use `--node-addr` only. Auth pairs (`quantus-miner/2`) also require `--auth-token-file` and `--tls-cert-sha256-file`. Probe `--help` before choosing.
- Token: PLK (12 decimals)
- Block reward: ~0.555 PLK total (~0.39 PLK miner share, rest to treasury)
- Telemetry: https://telemetry.quantus.cat/
- Explorer: https://explorer.quantus.com/
- Node binary: https://github.com/Quantus-Network/chain/releases/latest
- Miner binary: https://github.com/Quantus-Network/quantus-miner/releases/latest
- Telegram: https://t.me/quantusnetwork
- GitHub Issues: https://github.com/Quantus-Network/chain/issues
