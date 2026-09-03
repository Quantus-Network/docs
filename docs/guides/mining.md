---
sidebar_position: 1
title: Start Mining
---

# Start Mining

This guide connects a computer to the **Planck testnet** and starts the supported Quantus node and miner pair. Planck tokens have no monetary value and the network may reset.

## Before you start

You need a Quantus wallet with its 24-word recovery phrase. Keep that phrase offline. Never paste it into chat, email, a support ticket, or a command.

The verified script supports macOS, Linux x64, and WSL2 on Windows. Native Windows users can review the [desktop Miner App preview](/guides/miner-app).

## Three steps

### 1. Open Terminal

On Windows, open an Ubuntu WSL2 terminal. On macOS or Linux, open Terminal.

### 2. Run the verified installer

This downloads the script to disk, verifies its SHA-256 checksum, and only then runs it. It does not pipe remote code into a shell.

```bash
curl --proto '=https' --tlsv1.2 -fsS https://docs.quantus.com/scripts/quantus-mining.sh -o quantus-mining.sh && \
curl --proto '=https' --tlsv1.2 -fsS https://docs.quantus.com/scripts/quantus-mining.sh.sha256 -o quantus-mining.sh.sha256 && \
{ if command -v sha256sum >/dev/null 2>&1; then sha256sum -c quantus-mining.sh.sha256; else shasum -a 256 -c quantus-mining.sh.sha256; fi; } && \
chmod u+x quantus-mining.sh && ./quantus-mining.sh mine
```

The installer selects the published pair from the [compatibility manifest](/mining-compatibility.json): node `v0.10.0`, miner `v4.0.2`, and protocol `quantus-miner/2`. It verifies every release asset before installation. There are no version or network choices.

### 3. Enter your recovery phrase locally

The prompt is hidden. The phrase is used locally to derive your wormhole reward address, then discarded. It is not saved, logged, sent over the network, or placed in command history.

The installer names the node, detects a conservative CPU or GPU configuration, starts both processes, and prints status. Initial chain sync can take from minutes to hours and does not count as hands-on setup time.

## Know when it works

Run:

```bash
./quantus-mining.sh status
```

A complete success state shows:

| Field | Ready value |
| --- | --- |
| Network | `Planck testnet` |
| Compatibility | node `v0.10.0` + miner `v4.0.2` |
| Node | `Running` |
| Sync | `Synced` |
| Miner | `Running` |
| Hash rate | a live rate from the miner |
| Reward address | your public wormhole address |
| Telemetry | your node name at [telemetry.quantus.cat](https://telemetry.quantus.cat/) |

Confirm stop-start recovery once:

```bash
./quantus-mining.sh restart-check
```

## Daily commands

| Goal | Command |
| --- | --- |
| Start or resume | `./quantus-mining.sh mine` |
| Check readiness | `./quantus-mining.sh status` |
| Stop | `./quantus-mining.sh stop` |
| Reinstall the supported pair | `./quantus-mining.sh setup --force` |
| Change resource use | `./quantus-mining.sh config set CPU_WORKERS 4` |

## Security boundary

- Only port `30333` should be public for peer-to-peer networking.
- Keep miner `9833/UDP`, RPC `9944`, and metrics `9615` private and local.
- The miner reads its auth token and TLS pin from local files. Do not paste either value into chat or command arguments.
- The recovery phrase is entered only into the hidden local prompt.
- The reward preimage is stored locally with owner-only permissions because the current node requires it at startup.
- `status` redacts 64-character secret-like values from log excerpts.
- The installer refuses unsupported networks, protocols, release URLs, assets, and checksums.

## Compatibility policy

The machine-readable [compatibility manifest](/mining-compatibility.json) is the release source of truth. The current pair is grounded in the `v4.0.0` miner release note, which requires node `v0.10.0+`. The installer does not resolve independent `latest` releases.

The manifest currently publishes minimum OS versions as `not-published`. That is an owner fact still needed from the release team. It does not claim a launch date, mainnet support, or rewards with monetary value.

## One-copy AI prompt

```text
Help me start Quantus Planck testnet mining on this computer using https://docs.quantus.com/guides/mining and its compatibility manifest. Use the verified quantus-mining.sh flow and do not choose versions independently. Never ask me to paste, upload, reveal, or store my recovery phrase, private key, reward preimage, miner auth token, or TLS material in chat, command arguments, logs, telemetry, or a repository. Pause while I enter recovery words locally into the hidden prompt. Keep miner, RPC, and metrics ports private. Do not switch networks or claim monetary rewards. Finish only when status shows the network, supported pair, sync state, Mining state, hash rate, reward address, telemetry route, and a passed restart check.
```

## Fix one problem at a time

| Problem | One recovery action |
| --- | --- |
| Checksum failed | Delete the named download and run the verified installer again. |
| Unsupported platform | Use macOS, Linux x64, or WSL2 on an x64 Windows machine. |
| Installed pair is stale | Run `./quantus-mining.sh setup --force`. |
| Node or miner stopped | Run `./quantus-mining.sh mine`. |
| Sync still says `Syncing` | Leave the process running and check `status` later. |
| macOS blocks a binary | Run `xattr -d com.apple.quarantine ~/quantus-mining/bin/quantus-node ~/quantus-mining/bin/quantus-miner`. |
| No hash rate after sync | Run `./quantus-mining.sh setup --force` to restore the supported pair. |
| Computer is sluggish | Run `./quantus-mining.sh config set CPU_WORKERS 1`, then `./quantus-mining.sh restart-check`. |

For protocol development and manual commands, use the chain repository's [MINING.md](https://github.com/Quantus-Network/chain/blob/main/MINING.md). Report reproducible defects in [GitHub Issues](https://github.com/Quantus-Network/chain/issues).
