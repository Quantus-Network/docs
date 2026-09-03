---
name: mining
description: Safely start and verify Quantus Planck testnet mining with the official pinned installer.
user_invocable: true
---

# Quantus Mining

Use this skill only for the Planck testnet. Planck tokens have no monetary value and the network may reset.

## Sources of truth

- Human guide: https://docs.quantus.com/guides/mining/
- Compatibility manifest: https://docs.quantus.com/mining-compatibility.json
- Installer: https://docs.quantus.com/scripts/quantus-mining.sh

The supported pair is node `v0.10.0`, miner `v4.0.2`, and protocol `quantus-miner/2`. The compatibility evidence is the official miner `v4.0.0` release note, which requires node `v0.10.0+`. Never resolve node and miner `latest` independently.

## Safety rules

1. Never ask the user to paste, upload, reveal, or store a recovery phrase, seed, private key, reward preimage, miner auth token, or TLS key in chat, command arguments, logs, telemetry, or a repository.
2. The user enters recovery words locally into the installer's hidden prompt. Pause while they do it. Do not inspect terminal input.
3. Download the installer to disk and verify its published SHA-256 file before execution. Never use a pipe-to-shell command.
4. Let the installer read the supported release pair from the compatibility manifest and verify every asset. Do not supply version overrides.
5. Keep miner `9833/UDP`, RPC `9944`, and metrics `9615` private. Only peer-to-peer port `30333` may be public.
6. Do not switch to mainnet or claim a launch date, release pair, reward value, or minimum OS version unless the manifest publishes it.
7. Finish only after the redacted status output shows the network, supported pair, node, sync, miner, hash rate, reward address, telemetry route, and restart result.

## Workflow

### 1. Confirm prerequisites

The user needs a Quantus wallet and its offline 24-word recovery phrase. If either is missing, stop and direct them to the official wallet first.

### 2. Detect the platform

The verified script supports macOS, Linux x64, and WSL2 on x64 Windows. Native Windows users may use the Miner App preview, but explain that `miner-v0.6.1` does not yet pin or verify its runtime downloads.

### 3. Run the verified flow

Have the user run the exact block from the visible guide at https://docs.quantus.com/guides/mining/. It downloads `quantus-mining.sh`, downloads `quantus-mining.sh.sha256`, verifies the file, and runs:

```bash
./quantus-mining.sh mine
```

Do not replace this with manual release downloads. The script chooses conservative CPU or GPU defaults and asks only for the local hidden wallet input.

### 4. Verify

Run:

```bash
./quantus-mining.sh status
```

`Overall: MINING` means the node is running, sync is complete, the miner is running, and a hash-rate line is present. If it says `STARTING`, wait for sync and check again. If it says `STOPPED`, run `./quantus-mining.sh mine`.

Then test stop-start recovery:

```bash
./quantus-mining.sh restart-check
```

Do not mark the task complete unless it prints `Restart recovery: PASSED` and the following status contains no secrets.

## One recovery action per failure

| Failure | Action |
| --- | --- |
| Checksum mismatch | Delete the named download and rerun the verified block. |
| Unsupported platform | Move to macOS, Linux x64, or WSL2 on x64 Windows. |
| Pair mismatch | Run `./quantus-mining.sh setup --force`. |
| Node or miner stopped | Run `./quantus-mining.sh mine`. |
| Still syncing | Leave it running and check `status` later. |
| Machine sluggish | Set `CPU_WORKERS` to 1 and run `restart-check`. |
| No hash rate after sync | Run `setup --force` to reinstall the supported pair. |

## Completion report

Report only non-secret facts: operating system, architecture, Planck testnet, node and miner versions, process states, sync state, hash-rate summary, public reward address, public telemetry node name, and restart result. Redact any 64-character hex value found in logs. Never copy raw logs into chat.
