---
sidebar_position: 1
title: Mining and Running a Node
---

# Mining and Running a Node

This guide covers connecting to the Quantus Planck testnet and mining. Works on macOS and Linux (including WSL2 on Windows). 

Use the **Copy Context** button at the top of this page to copy everything as Markdown -- the full guide plus an AI mining skill. Paste it to an agent like Claude Code to be walked through setup interactively, or keep it as an offline reference.

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
| **inner_hash** | 32-byte preimage | Pass to the node via `--rewards-inner-hash` |
| **Secret** | Private key proving ownership | This can be recovered with your 24 word phrase |

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

The script generates your wormhole inner hash, node identity, and a config file at `~/quantus-mining/mining.conf`. It can deploy either **native binaries** or a **Docker Compose stack** — you choose during setup.

### Deployment modes

| Mode | Command | Best for |
|------|---------|----------|
| **Binary** (default) | `./quantus-mining.sh setup` or `setup --mode binary` | macOS; Linux x86_64 |
| **Docker** | `./quantus-mining.sh setup --mode docker` | Linux ARM64, containerized deploy, or when you prefer not to install binaries locally |

**Binary mode** downloads `quantus-node` and `quantus-miner` into `~/quantus-mining/bin/`.

**Docker mode** requires Docker Desktop (or Docker Engine) with Compose v2 (`docker compose`) and a running daemon. It pulls `ghcr.io/quantus-network/quantus-node` and `ghcr.io/quantus-network/quantus-miner` (release tags from GitHub) and installs a compose stack under `~/quantus-mining/docker/` (`docker-compose.yml`, `init-node.sh`, node keys, and chain data).

**Linux ARM64:** there is no native `quantus-miner` release for Linux ARM64. Use `--mode docker` or an x86_64 host.

### Running the stack

The same commands work for both modes; `RUN_MODE` in `mining.conf` selects binary vs Docker.

**One terminal:** `./quantus-mining.sh start`

- **Binary:** node output in your terminal (foreground); miner runs in the background (`~/quantus-mining/logs/miner.log`). Ctrl+C stops both.
- **Docker:** both containers attach to your terminal. Ctrl+C stops both.

**Two terminals (matches the manual steps below):** run `./quantus-mining.sh start-node` in one terminal, then `./quantus-mining.sh start-miner` in another after the node is listening.

Add `-d` or `--detach` to run both in the background. Stop with `./quantus-mining.sh stop` from any terminal (works for foreground and detached runs).

**Docker logs (detached or troubleshooting):**

```bash
cd ~/quantus-mining/docker && docker compose logs -f
```

Manage settings with `./quantus-mining.sh config show` or `./quantus-mining.sh config set CPU_WORKERS 4`. Editable keys: `NODE_NAME`, `CPU_WORKERS`, `GPU_DEVICES`, `MINER_LISTEN_PORT`, `CHAIN`. In Docker mode, the script regenerates `docker/.env` on start after config changes.

GPU mining is recommended when available. Mining rewards accumulate at your wormhole address and appear in the wallet app, ready to spend.

Example config template: [mining.conf.example](/scripts/mining.conf.example).

## Manual Installation (Mac / Linux)

### 1. Download the Node Binary

Get the latest `quantus-node` binary for your platform from [GitHub Releases](https://github.com/Quantus-Network/chain/releases/latest). 

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
Copy the 24 word secret phrase from your wallet app.

**Note: Save this secret phrase securely and do not share with anyone. It is used to access your rewards, move funds, and derive any information you need in the future.**

When using the below command, make sure to put your secret words in "quotation marks".

Save the `Inner Hash`:

```sh
./quantus-node key quantus --scheme wormhole --words "your secret words"
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

### 5. Start the Miner

Download the miner binary from [Miner Releases](https://github.com/Quantus-Network/quantus-miner/releases/latest).

**Open a new terminal window (cmd + t). Let the node run in the original terminal.**

**macOS only:** 

```bash
xattr -d com.apple.quarantine quantus-miner-macos-aarch64 && chmod u+x quantus-miner-macos-aarch64
```

Wait for the node logs to show the miner server is listening, then run the following command in the **separate terminal** (if not on Apple Silicon, replace `quantus-miner-macos-aarch64` with your platform's binary name):

```bash
./quantus-miner-macos-aarch64 serve --cpu-workers 4 --gpu-devices 0 --node-addr 127.0.0.1:9833
```

Depending on your machine and resources you can adjust `--gpu-devices` and `--cpu-workers` to see what provides the best balance of hash rate and system usability.

The above command is fairly conservative for most modern hardware. 

For example if you want to use your GPU and have many CPU cores available you could run 

```bash
./quantus-miner-macos-aarch64 serve --cpu-workers 8 --gpu-devices 1 --node-addr 127.0.0.1:9833
```

## Monitoring

### Your Rewards

Rewards accumulate at your wormhole address as you mine. The wallet app supports wormhole addresses and encrypted accounts, so if you mine with the same seed phrase as your app wallet, rewards appear in the app and are spendable directly from your wormhole balance -- there is no separate claiming step.

### Monitoring Your Node
- **Telemetry dashboard:** [telemetry.quantus.cat](https://telemetry.quantus.cat/) -- find your node by name
- **Prometheus metrics (detailed node metrics):** `http://localhost:9615/metrics`
- **RPC endpoint:** `http://localhost:9944`
- **Check your address in the explorer:** Your wormhole address is in the `Address` field from key generation, or in your node's startup logs.



### **Logs & Diagnostics**

**Binary / manual install:**

```bash
# Real-time logs
tail -f ~/.local/share/quantus-node/chains/planck/network/quantus-node.log

# Or run with verbose logging
RUST_LOG=info ./quantus-node [options]
```

**Docker (automated setup with `RUN_MODE=docker`):**

```bash
cd ~/quantus-mining/docker && docker compose logs -f
# Chain data on disk: ~/quantus-mining/docker/node-data/
```

#### **Inspect your node's P2P identity:**

```bash
./quantus-node key inspect-node-key --file node_key.p2p
```

## Security Best Practices

### Key Management

- **Back up your seed phrase securely** 

### Node Security

- **Firewall:** Only expose port 30333 (P2P). Keep 9833 (miner), 9944 (RPC), and 9615 (metrics) on localhost.
- **Updates:** Check [GitHub Releases](https://github.com/Quantus-Network/chain/releases/latest) for new versions regularly
- **Monitoring:** Watch for unusual peer counts, sync stalls, or dropped miner connections

### Testnet Disclaimer

Planck is testnet software for testing purposes only. Tokens have no monetary value. The network may be reset periodically, and breaking changes are expected between releases.


### Getting Help

- **GitHub Issues:** [Report bugs](https://github.com/Quantus-Network/chain/issues)
- **Telegram:** [Quantus community](https://t.me/quantusnetwork)
- **Research forum:** [research.quantus.com](https://research.quantus.com) -- deeper technical discussion with the Quantus team