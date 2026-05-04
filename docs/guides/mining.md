---
sidebar_position: 1
title: Mining and Running a Node
---

# Mining and Running a Node

This guide covers connecting to the Quantus Planck testnet and mining. Works on macOS and Linux (including WSL2 on Windows). 

Use the buttons in the top-right corner of this page to copy the full guide as Markdown, or to copy an AI mining skill you can give to an agent like Claude Code to walk you through setup interactively.

## Prerequisites

Before starting, you will need:

1. **Quantus wallet.** Download the [Quantus wallet](https://linktr.ee/quantusnetwork) to hold funds, send transactions, and eventually claim your mining rewards.

2. **A mnemonic / seed phrase.** You can create one in the wallet app or in the CLI. 

3. **A wormhole address for rewards.** The chain only accumulates mining rewards to **wormhole addresses** -- not regular wallet addresses. Rewards sitting at a wormhole can later be claimed to either another wormhole address or a dilithium (regular wallet) address. You'll generate your wormhole address in the setup below.

## Understanding Wormhole Addresses

Mining rewards are sent to a **wormhole address** derived from a 32-byte preimage you generate during setup (aka your inner hash). 

This is privacy-preserving by default. All miners use must claim to wormhole addresses.

Wormhole addresses look identical to regular transparent addresses, but they have a separate derivation path. 

**If you already have an existing wallet:** You can derive a wormhole keypair from an existing mnemonic or seed instead of generating a fresh one. This is the recommended approach if you are mining for the first time. 

Currently, our mobile app only supports transparent addresses. So this guide will walk you through mining to a wormhole address and claiming into your transparent address so that you can see your rewards in the app, and use your tokens without depending on the CLI. 

During setup you will run `key quantus --scheme wormhole`, which outputs three values:

| Value | What it is | What to do |
|-------|-----------|------------|
| **Address** | Your wormhole address (where rewards are sent) | Note for monitoring |
| **inner_hash** | 32-byte preimage | Pass to the node via `--rewards-inner-hash` |
| **Secret** | Private key proving ownership | This can be recovered with your 24 word phrase |

The node derives your wormhole address from the `inner_hash` and logs it on startup.

The most important thing to back up is your 24 word phrase. 

You shoould keep both your 24 word phrase and your secret secure and do not share either with anyone. 

---

## Installation (Mac / Linux)

### 1. Download the Node Binary

Get the latest `quantus-node` binary for your platform from [GitHub Releases](https://github.com/Quantus-Network/chain/releases/latest). 

Download it in your working directory.

You will need to extract it into your working directory. To do this on MacOS simply double click.

Note: That aarch64-apple is for apple silicon chips (M1 and above), and x86-apple is for intel based Macs.

Now open your terminal, generat your node key, inner hash, and run the node in this terminal window. 

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

**Note: Save this secret phrase securely and do not share with anyone. It is used to claim rewards, move funds, and derive any information you need in the future.**

When using the below command, make sure to put your secret words in "quotation marks".

Save the `Inner Hash`:

```sh
./quantus-node key quantus --scheme wormhole --words "your secret words"
```

#### Alternatively, if you'd like to generate a separate wallet address from what you have in your wallet app you can use the command below:


```bash
./quantus-node key quantus --scheme wormhole
```

COPY the words from the output. That is your secret phrase

**Note: Save this secret phrase securely and do not share with anyone. It is used to claim rewards, move funds, and derive any information you need in the future.**


### 4. Start the Node
Note: In the below command the following arguments need to change:

`--name`

`--rewards-inner-hash`

Input any desired node name.

`node_key.p2p` file should be the same as default below (generated in step 2 above).

Your `inner-hash` will be displayed from the commands in the above steps.


```bash
./quantus-node \
  --name NAME YOUR NODE HERE \
  --validator \
  --miner-listen-port 9833 \
  --chain planck \
  --node-key-file node_key.p2p \
  --rewards-inner-hash PASTE YOUR INNER HASH HERE \
  --max-blocks-per-request 64 \
  --sync full
```

### 5. Start the Miner

Download the miner binary from [Miner Releases](https://github.com/Quantus-Network/quantus-miner/releases/latest).

**Open a new terminal window (cmd + t). Let the node run in the original terminal.**

**macOS only:** 

```bash
xattr -d com.apple.quarantine quantus-miner-macos-aarch64 && chmod u+x quantus-miner-macos-aarch64
```

#### Wait for the node logs to show the miner server is listening, then run the following command in a **separate terminal**:

**Note (if not using apple silicon):** Replace "./quantus-miner-macos-aarch64" with the name of your file.

```bash
./quantus-miner-macos-aarch64 serve --cpu-workers 4 --gpu-devices 0 --node-addr 127.0.0.1:9833
```

Depending on your machine and resources you can adjust, `--gpu-devices 0 --cpu-workers 4` to see what provides the best balance of hash rate and system usability.

The above command is fairly conservative for most modern hardware. 

For example if you want to use your GPU and have many CPU cores available you could run 

```bash
./quantus-miner-macos-aarch64 serve --cpu-workers 8 --gpu-devices 1 --node-addr 127.0.0.1:9833
```

## Monitoring & Claiming Rewards

### **Claiming Rewards**

#### 1. Download quantus-cli
Download the latest quantus-cli archive into the same directory:
https://github.com/Quantus-Network/quantus-cli/releases/latest


#### 2. Extract, make executable, and clear the macOS quarantine flag:

```bash
tar -xzf quantus-cli-*.tar.gz --strip-components=1
chmod +x quantus
xattr -d com.apple.quarantine quantus
./quantus --version
```
#### 3. Import your secret phrase into a new wallet named mining (use the same words):

```bash
./quantus wallet import --name mining --mnemonic "YOUR SECRET WORDS"
```

#### 4. Collect your mined tokens via the public Planck RPC:

```bash
./quantus \
  --node-url wss://a1-planck.quantus.cat \
  --verbose --wait-for-transaction \
  wormhole collect-rewards --wallet mining
```

### Monitoring Your Node
- **Telemetry dashboard:** [telemetry.quantus.cat](https://telemetry.quantus.cat/) -- find your node by name
- **Prometheus metrics (detailed node metrics):** `http://localhost:9615/metrics`
- **RPC endpoint:** `http://localhost:9944`
- **Check your address in the explorer:** Your wormhole address is in the `Address` field from key generation, or in your node's startup logs.



### **Logs & Diagnostics**
```bash
# Real-time logs
tail -f ~/.local/share/quantus-node/chains/planck/network/quantus-node.log

# Or run with verbose logging
RUST_LOG=info quantus-node [options]
```

#### **Inspect your node's P2P identity:**

```bash
./quantus-node key inspect-node-key --file ~/.quantus/node_key.p2p
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


### FAQ