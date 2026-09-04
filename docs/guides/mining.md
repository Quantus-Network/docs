---
sidebar_position: 1
title: Mining and Running a Node
---

# Mining and Running a Node

This guide covers connecting to the Quantus Planck testnet and mining. The setup script below runs on macOS and Linux, including WSL2 on Windows.

**On Windows without WSL2?** Use the [Miner App](https://github.com/Quantus-Network/quantus-apps/releases/latest) (`quantus_miner_windows.zip`) instead. It is a desktop app that downloads the node for you and handles identity, mining, and rewards in one window, with no terminal.

Use the **Copy Context** button at the top of this page to copy everything as Markdown -- the full guide plus an AI mining skill. Paste it to an agent like Claude Code to be walked through setup interactively, or keep it as an offline reference.

If you use Claude Code, install the skill from disk in one command instead of pasting:

```bash
mkdir -p ~/.claude/skills/mining && curl -fsSL https://docs.quantus.com/skills/mining-skill.md -o ~/.claude/skills/mining/SKILL.md
```

Then run `/mining`. The skill walks the same steps as this guide, and it probes the binaries you actually downloaded before starting anything, so it will not hand you a mismatched node and miner pair.

## Prerequisites

Before starting, you will need:

1. **Quantus wallet.** Download the [Quantus wallet](https://linktr.ee/quantusnetwork) to hold funds, send transactions, and spend your mining rewards.

2. **A mnemonic / seed phrase.** You can create one in the wallet app or in the CLI.

3. **A wormhole address for rewards.** The chain only accumulates mining rewards to **wormhole addresses** -- not regular wallet addresses. The wallet app supports wormhole addresses and encrypted accounts, so rewards mined to your wormhole address show up in the app and can be spent directly from your wormhole balance -- no separate claiming step. You'll generate your wormhole address in the setup below.

## Understanding Wormhole Addresses

Mining rewards are sent to a **wormhole address** derived from a 32-byte preimage you generate during setup (aka your inner hash).

This is privacy-preserving by default. All mining rewards are paid to wormhole addresses.

Wormhole addresses look identical to regular transparent addresses, but they have a separate derivation path.

**If you already have an existing wallet:** You can derive a wormhole keypair from an existing mnemonic or seed instead of generating a fresh one. This is the recommended approach if you are mining for the first time -- use the same seed phrase as your wallet app, and your mining rewards will appear in the app automatically, spendable straight from your wormhole balance.

During setup you will run `key quantus --scheme wormhole`, which outputs three values:

| Value | What it is | What to do |
|-------|-----------|------------|
| **Address** | Your wormhole address (where rewards are sent) | Note for monitoring |
| **Inner Hash** | 32-byte preimage | Pass to the node via `--rewards-inner-hash` |
| **Secret phrase** | The mnemonic that proves ownership | Back up securely -- this recovers everything |

The node derives your wormhole address from the `inner_hash` and logs it on startup.

The most important thing to back up is your 24 word phrase.

You should keep both your 24 word phrase and your secret secure and do not share either with anyone.

---

## Automated Setup

For a guided terminal workflow, use the mining setup script (macOS, Linux, or WSL2):

```bash
curl -fsSL https://docs.quantus.com/scripts/quantus-mining.sh -o quantus-mining.sh
chmod +x quantus-mining.sh
./quantus-mining.sh setup
./quantus-mining.sh start
```

The script generates your wormhole inner hash, node identity, and a config file at `~/quantus-mining/mining.conf`. It downloads native `quantus-node` and `quantus-miner` binaries into `~/quantus-mining/bin/`. GPU mining is recommended; the miner runs on the host so it can use Metal / Vulkan / DirectX.

The script checks the downloaded pair's `--help` output and only passes auth/TLS flags when **both** binaries support miner QUIC auth (`quantus-miner/2`). Mixing an auth-capable node with a pre-auth miner (or the reverse) is rejected. Pin a matching pair with `NODE_VERSION` / `MINER_VERSION` in `mining.conf` (or `./quantus-mining.sh config set NODE_VERSION <tag>`), then run `./quantus-mining.sh setup --force` to download those tags. Environment variables of the same name override the file. Unset pins fetch GitHub `releases/latest` independently and may not match.

**Linux ARM64:** there is no native `quantus-miner` release. Mine from macOS or Linux x86_64.

If an older installer created a Docker stack under `~/quantus-mining/docker/`, `./quantus-mining.sh stop` and `uninstall` still shut it down. New Docker setup is not supported (`setup --mode docker` is rejected). After stopping, migrate with `./quantus-mining.sh setup --force`.

### Running the stack

**One terminal:** `./quantus-mining.sh start`

Node output in your terminal (foreground); miner runs in the background (`~/quantus-mining/logs/miner.log`). Ctrl+C stops both.

**Two terminals (matches the manual steps below):** run `./quantus-mining.sh start-node` in one terminal, then `./quantus-mining.sh start-miner` in another after the node is listening.

Add `-d` or `--detach` to run both in the background. Stop with `./quantus-mining.sh stop` from any terminal (works for foreground and detached runs).

Manage settings with `./quantus-mining.sh config show` or `./quantus-mining.sh config set CPU_WORKERS 4`. Editable keys: `NODE_NAME`, `CPU_WORKERS`, `GPU_DEVICES`, `MINER_LISTEN_PORT`, `CHAIN`, `NODE_VERSION`, `MINER_VERSION`. Changing version pins does not swap binaries until you re-run `setup --force`.

GPU mining is recommended when available. Mining rewards accumulate at your wormhole address and appear in the wallet app, ready to spend.

The script wires miner authentication when the downloaded pair supports it: after the node starts it reads `miner-auth-token` and `miner-tls-cert-sha256` from the node's chain directory and passes them to the miner. You do not need to copy those values by hand. If the pair predates miner auth, the script starts without those flags.

Example config template: [mining.conf.example](/scripts/mining.conf.example).

## Manual Installation (Mac / Linux)

### 1. Download the Node Binary

Get a `quantus-node` binary that matches your miner from [GitHub Releases](https://github.com/Quantus-Network/chain/releases). Do not mix `chain/releases/latest` with an unrelated `quantus-miner` latest tag — they are published independently and may not speak the same miner protocol.

Download it in your working directory.

Extract it into your working directory (on macOS, double-clicking the archive works).

Note: `aarch64-apple` builds are for Apple Silicon Macs (M1 and above); `x86-apple` is for Intel-based Macs.

Now open your terminal to generate your node key and inner hash, and run the node in this terminal window.

**macOS only -- fix Gatekeeper permissions:**

```bash
xattr -d com.apple.quarantine quantus-node
chmod u+x quantus-node
```

### 2. Generate Node Identity

```bash
./quantus-node key generate-node-key --file node_key.p2p
```

### 3. Generate Inner Hash
Have the 24 word secret phrase from your wallet app ready.

**Note: Keep this secret phrase secure and do not share it with anyone. It is used to access your rewards, move funds, and derive any information you need in the future.**

Run the command below. It prompts for your 24 words and reads them **without echoing** -- the phrase is never passed on the command line, so it stays out of your shell history.

Save the `Inner Hash` from the output:

```sh
./quantus-node key quantus --scheme wormhole --words
```

Alternatively, to generate a fresh wallet separate from the one in your wallet app:

```bash
./quantus-node key quantus --scheme wormhole
```

Copy the words from the output -- that is your secret phrase.

**Note: Save this secret phrase securely and do not share with anyone. It is used to access your rewards, move funds, and derive any information you need in the future.**


### 4. Start the Node

Replace the two placeholders before running:

- `<YOUR_NODE_NAME>` -- any name you like (this is how your node appears on [telemetry](https://telemetry.quantus.cat/))
- `<YOUR_INNER_HASH>` -- the `inner_hash` value from step 3

`node_key.p2p` is the file generated in step 2.

```bash
./quantus-node \
  --name <YOUR_NODE_NAME> \
  --validator \
  --miner-listen-port 9833 \
  --chain planck \
  --node-key-file node_key.p2p \
  --rewards-inner-hash <YOUR_INNER_HASH> \
  --max-blocks-per-request 64 \
  --sync full
```
#### Note on Syncing
Once you begin syncing your node, wait until the node is fully synced before you begin mining. Blocks mined before your node reaches the chain tip are orphans and earn nothing (the miner pauses automatically if your node has no peers).

Sync time grows with the chain: expect anywhere from ~15 minutes to a couple of hours depending on your hardware and connection. Your node is synced when the log switches from `Syncing` to `Idle` at the current tip.

**Run the node version that matches the network.** If your node stalls mid-sync with `Verification failed` errors and drops to 0 peers, your node version is out of step with the network -- check [Releases](https://github.com/Quantus-Network/chain/releases) and community announcements for which version the network is currently running.

On first start with `--miner-listen-port`, the node writes miner auth material under the chain directory (token is **not** logged -- read the file):

| File | Purpose |
|------|---------|
| `miner-auth-token` | Shared secret the miner sends in `Ready`. Mode `0600`. Never put this on the command line or in logs. |
| `miner-tls-cert-sha256` | SHA-256 of the miner QUIC cert. Miners must pin this. Also printed in node logs. |
| `miner-tls-cert.der` / `miner-tls-key.der` | Node TLS material (do not copy the private key to miners). |

Default chain directory:

| Platform | Path |
|----------|------|
| Linux | `~/.local/share/quantus-node/chains/planck/` |
| macOS | `~/Library/Application Support/quantus-node/chains/planck/` |

Wait until logs show the miner server is listening (and the auth/TLS file paths) before starting the miner. If miner-server startup fails, the node exits -- it does not fall back to local mining.

### 5. Start the Miner

Download the miner binary from [Miner Releases](https://github.com/Quantus-Network/quantus-miner/releases). Node and miner versions must be a matching pair: the authenticated wire protocol ALPN is `quantus-miner/2`. Confirm `quantus-node --help` lists `--miner-auth-token-file` and `quantus-miner serve --help` lists `--auth-token-file` before using the commands below. A mismatched pair fails at TLS handshake with "no application protocol". Older releases (node v0.9.0, miner v3.3.1 and earlier) do not include miner auth — omit the auth/TLS flags and connect with `--node-addr` only.

**Open a new terminal window (cmd + t). Let the node run in the original terminal.**

**macOS only:**

```bash
xattr -d com.apple.quarantine quantus-miner-macos-aarch64 && chmod u+x quantus-miner-macos-aarch64
```

Wait for the node logs to show the miner server is listening, then run the following in the **separate terminal**. Quote `CHAIN_DIR` — the macOS path contains a space. If not on Apple Silicon, replace `quantus-miner-macos-aarch64` with your platform's binary name.

```bash
CHAIN_DIR="$HOME/Library/Application Support/quantus-node/chains/planck"
# Linux: CHAIN_DIR="$HOME/.local/share/quantus-node/chains/planck"

./quantus-miner-macos-aarch64 serve \
  --cpu-workers 4 \
  --gpu-devices 0 \
  --node-addr 127.0.0.1:9833 \
  --auth-token-file "$CHAIN_DIR/miner-auth-token" \
  --tls-cert-sha256-file "$CHAIN_DIR/miner-tls-cert-sha256"
```

Prefer `--auth-token-file` / `--tls-cert-sha256-file` over inline `--auth-token` / `--tls-cert-sha256` so the secret is not stored in shell history. When the node/miner pair includes miner auth, both flags are required; a wrong token or TLS pin is a permanent error (the miner will not reconnect-loop). On pre-auth releases, omit those flags.

Depending on your machine and resources you can adjust `--gpu-devices` and `--cpu-workers` to see what provides the best balance of hash rate and system usability.

The above command is fairly conservative for most modern hardware.

For example if you want to use your GPU and have many CPU cores available you could run

```bash
CHAIN_DIR="$HOME/Library/Application Support/quantus-node/chains/planck"
# Linux: CHAIN_DIR="$HOME/.local/share/quantus-node/chains/planck"

./quantus-miner-macos-aarch64 serve \
  --cpu-workers 8 \
  --gpu-devices 1 \
  --node-addr 127.0.0.1:9833 \
  --auth-token-file "$CHAIN_DIR/miner-auth-token" \
  --tls-cert-sha256-file "$CHAIN_DIR/miner-tls-cert-sha256"
```

If the miner exits immediately, it is usually auth or version mismatch: confirm both files exist, that you waited for the miner server to listen, and that node and miner releases match (`quantus-miner/2`). A wrong token or TLS pin is a permanent error -- re-read the files (the token is never logged).

## Monitoring

### Your Rewards

Rewards accumulate at your wormhole address as you mine. The wallet app supports wormhole addresses and encrypted accounts, so if you mine with the same seed phrase as your app wallet, rewards appear in the app and are spendable directly from your wormhole balance -- there is no separate claiming step.

### Monitoring Your Node
- **Telemetry dashboard:** [telemetry.quantus.cat](https://telemetry.quantus.cat/) -- find your node by name
- **Prometheus metrics (detailed node metrics):** `http://localhost:9615/metrics`
- **RPC endpoint:** `http://localhost:9944`
- **Check your address in the explorer:** Your wormhole address is in the `Address` field from key generation, or in your node's startup logs.



### **Logs & Diagnostics**

```bash
# Linux
tail -f ~/.local/share/quantus-node/chains/planck/network/quantus-node.log

# macOS
tail -f ~/Library/Application\ Support/quantus-node/chains/planck/network/quantus-node.log

# Or run with verbose logging
RUST_LOG=info ./quantus-node [options]
```

#### **Inspect your node's P2P identity:**

```bash
./quantus-node key inspect-node-key --file node_key.p2p
```

## Security Best Practices

### Key Management

- **Back up your seed phrase securely**

### Node Security

- **Firewall:** Only expose port 30333 (P2P). Keep 9833/UDP (miner), 9944 (RPC), and 9615 (metrics) on localhost. The miner port binds `0.0.0.0` -- reachability is entirely your firewall. Auth + TLS pinning do **not** make it safe to publish to the internet.
- **Miner secrets:** Treat `miner-auth-token` like a password. Back it up with the same care as other node files; anyone with the token and network access to port 9833 can submit job results and observe mining jobs.
- **Remote miners:** Put node and miners on a private network or VPN (WireGuard, Tailscale, VPC). Do not open 9833/UDP to `0.0.0.0/0`.
- **Updates:** Check [GitHub Releases](https://github.com/Quantus-Network/chain/releases/latest) for new versions regularly. Node and miner must ship the same miner protocol (`quantus-miner/2`).
- **Monitoring:** Watch for unusual peer counts, sync stalls, or dropped miner connections

### Testnet Disclaimer

Planck is testnet software for testing purposes only. Tokens have no monetary value. The network may be reset periodically, and breaking changes are expected between releases.


### Getting Help

- **GitHub Issues:** [Report bugs](https://github.com/Quantus-Network/chain/issues)
- **Telegram:** [Quantus community](https://t.me/quantusnetwork)
- **Research forum:** [research.quantus.com](https://research.quantus.com) -- deeper technical discussion with the Quantus team