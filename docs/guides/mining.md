---
sidebar_position: 1
title: Start Mining
---

# Start Mining

This guide connects a computer to **Quantus mainnet** and starts the supported node and miner pair. Mainnet QTC has value, so treat your recovery phrase like the keys to a bank account.

## Set up with an agent

Paste this into your coding agent:

```text
Fetch and follow https://docs.quantus.com/agent-setup/prompt.md to set up Quantus mining on this computer.
```

The agent handles setup and checks. Enter wallet recovery words only in your private local terminal, never in chat. Prefer manual setup? Continue below.

## Before you start

Have **100 GB free on the node data drive**, as specified by the [pinned node guide](https://github.com/Quantus-Network/chain/blob/v1.0.1/MINING.md#system-requirements). Windows setup checks this before downloads or wallet entry. `preflight` checks Windows platform and storage without starting anything. To use another drive, set `QUANTUS_NODE_DATA_PATH` to your chosen data folder in the same shell before setup and future starts.

You need a Quantus wallet with its 24-word recovery phrase. If you do not have one, install the Quantus Wallet app from [Tools and Community](/reference/tools-and-community) and create a wallet there: mining rewards to that phrase then appear in the app and are spendable directly. Write the phrase on paper and keep it offline. Never paste it into chat, email, a support ticket, or a command.

There are two verified installers, one per shell, and they behave identically: `quantus-mining.sh` for macOS, Linux x64, and WSL2, and `quantus-mining.ps1` for native Windows 10/11 x64. Both read the same [compatibility manifest](/mining-compatibility.json), verify the same checksums, ask for the recovery phrase the same way, and print the same status. On Windows, use PowerShell rather than WSL2: the miner needs the native graphics driver to use the GPU. The [desktop Miner App](/guides/miner-app) remains a preview and is not the verified path.

## Three steps

### 1. Open a shell

On macOS or Linux, open Terminal. On Windows, press the Windows key, type `PowerShell`, and press Enter. No WSL is needed.

### 2. Run the verified installer

This downloads the script to disk, verifies its SHA-256 checksum, and only then runs it. It does not pipe remote code into a shell.

macOS, Linux, or WSL2:

```bash
curl --proto '=https' --tlsv1.2 -fsS https://docs.quantus.com/scripts/quantus-mining.sh -o quantus-mining.sh && \
curl --proto '=https' --tlsv1.2 -fsS https://docs.quantus.com/scripts/quantus-mining.sh.sha256 -o quantus-mining.sh.sha256 && \
{ if command -v sha256sum >/dev/null 2>&1; then sha256sum -c quantus-mining.sh.sha256; else shasum -a 256 -c quantus-mining.sh.sha256; fi; } && \
chmod u+x quantus-mining.sh && ./quantus-mining.sh mine
```

Windows PowerShell:

```powershell
[Net.ServicePointManager]::SecurityProtocol = 'Tls12'
Invoke-WebRequest -UseBasicParsing https://docs.quantus.com/scripts/quantus-mining.ps1 -OutFile quantus-mining.ps1
Invoke-WebRequest -UseBasicParsing https://docs.quantus.com/scripts/quantus-mining.ps1.sha256 -OutFile quantus-mining.ps1.sha256
if ((Get-FileHash quantus-mining.ps1 -Algorithm SHA256).Hash.ToLower() -ne (Get-Content quantus-mining.ps1.sha256).Split(' ')[0]) { throw 'Checksum mismatch. Delete both files and retry.' }
Unblock-File quantus-mining.ps1
powershell -ExecutionPolicy Bypass -File .\quantus-mining.ps1 mine
```

The installer selects the published pair from the [compatibility manifest](/mining-compatibility.json): node `v1.0.1`, miner `v4.2.0`, and protocol `quantus-miner/2`. It verifies every release asset before installation. There are no version or network choices.

### 3. Enter your recovery phrase locally

The prompt is hidden. The phrase is used locally to derive your wormhole reward address, then discarded. It is not saved, logged, sent over the network, or placed in command history.

The installer names the node, detects a conservative CPU or GPU configuration, starts both processes, and prints status. Initial chain sync downloads and executes every block, which is the only sync mode the node supports. Mainnet is young, so today that is minutes rather than hours, and it grows with the chain. The miner starts working the moment the node reports it is synced.

## Know when it works

Run:

```bash
./quantus-mining.sh status
```

On Windows, every command is the same with `.\quantus-mining.ps1` in place of `./quantus-mining.sh`. While syncing, the Windows status line also shows the current block, the target, the rate, and the time left.

A complete success state shows:

| Field | Ready value |
| --- | --- |
| Network | `mainnet` |
| Compatibility | node `v1.0.1` + miner `v4.2.0` |
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
| Update to the supported pair, keeping your reward address | `./quantus-mining.sh setup --force` |
| Change resource use | `./quantus-mining.sh config set CPU_WORKERS 4` |

## Coming from Planck

Planck was the public testnet and is retired. Mainnet does not share its history, database, or balances.

- Run `./quantus-mining.sh setup --force` (or `.\quantus-mining.ps1 setup -Force`). It installs the mainnet pair and keeps your existing reward preimage, address, node name, and resource settings. It does not ask for the recovery phrase again.
- The node syncs mainnet from genesis into `chains/mainnet/`. Planck data under `chains/planck/` is never reused and can be deleted.
- Never pass `--force-authoring` to join mainnet. That flag only bootstraps a brand-new network.

## Security boundary

- Only port `30333` should be public for peer-to-peer networking.
- Keep miner `9833/UDP`, RPC `9944`, and metrics `9615` private and local.
- The miner reads its auth token and TLS pin from local files. Do not paste either value into chat or command arguments.
- The recovery phrase is entered only into the hidden local prompt.
- The reward preimage is stored locally with owner-only permissions because the current node requires it at startup.
- `status` redacts 64-character secret-like values from log excerpts.
- The installer refuses unsupported networks, protocols, release URLs, assets, and checksums.

## Compatibility policy

The machine-readable [compatibility manifest](/mining-compatibility.json) is the release source of truth. The current pair is node `v1.0.1`, the first release carrying the mainnet chain spec, with miner `v4.2.0`. Both were verified together on real hardware against mainnet: the node joins with peers and writes its miner auth files, and the miner authenticates and receives work. The installer does not resolve independent `latest` releases. Node `v1.0.1` publishes no Intel macOS build, so Intel Macs are refused rather than paired with a missing node.

The manifest currently publishes minimum OS versions as `not-published`. That is an owner fact still needed from the release team. The manifest does not promise earnings: whether a machine wins blocks depends on its share of total network hash rate.

## Fix one problem at a time

| Problem | One recovery action |
| --- | --- |
| Checksum failed | Delete the named download and run the verified installer again. |
| Unsupported platform | Use Apple Silicon macOS, Linux x64, or 64-bit Windows 10/11. Intel macOS and Windows on ARM have no published node for the current pair. |
| PowerShell refuses to run the script | Run `Unblock-File .\quantus-mining.ps1`, or start it with `powershell -ExecutionPolicy Bypass -File .\quantus-mining.ps1 mine`. |
| Windows: sync shows peers but the block number is not moving | Check free disk space, peer connectivity and disk activity, then compare block progress with `status`. Do not disable antivirus protection or add exclusions as a default fix. |
| Installed pair is stale, or still on Planck | Run `./quantus-mining.sh setup --force`. Your reward address is kept. |
| Node or miner stopped | Run `./quantus-mining.sh mine`. |
| Sync still says `Syncing` | Leave the process running and check `status` later. |
| macOS blocks a binary | Run `xattr -d com.apple.quarantine ~/quantus-mining/bin/quantus-node ~/quantus-mining/bin/quantus-miner`. |
| No hash rate after sync | Run `status` and check the reported miner/protocol error. If the miner stopped, use `mine`. Do not reinstall or repeat wallet entry without diagnosing the failure. |
| Computer is sluggish | Run `./quantus-mining.sh config set CPU_WORKERS 1`, then `./quantus-mining.sh restart-check`. |

For protocol development and manual commands, use the chain repository's [MINING.md](https://github.com/Quantus-Network/chain/blob/main/MINING.md). Report reproducible defects in [GitHub Issues](https://github.com/Quantus-Network/chain/issues).
