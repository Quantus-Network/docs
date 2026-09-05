---
sidebar_position: 2
title: Miner App Preview
---

# Miner App Preview

The Quantus Miner App provides one desktop interface for wallet setup, node sync, CPU or GPU mining, hash rate, and rewards. Release `miner-v0.6.1` is a **preview**, not the verified beginner path.

The app downloads and starts node and miner binaries at runtime. It does not bundle them, pin the shared compatibility manifest, or verify their release checksums in this release. Use a dedicated Planck testnet wallet and do not use the app for assets with monetary value.

## Direct downloads

| Platform | Download | SHA-256 |
| --- | --- | --- |
| Windows x64 | [quantus_miner_windows.zip](https://github.com/Quantus-Network/quantus-apps/releases/download/miner-v0.6.1/quantus_miner_windows.zip) | `081308152ba6f9eba62b9ac143f8c9e115ffab400a978a9d03a996e55ece8ad1` |
| macOS | [quantus_miner_macos.zip](https://github.com/Quantus-Network/quantus-apps/releases/download/miner-v0.6.1/quantus_miner_macos.zip) | `fb4769d4c1e8ccd3c480e0caeca07c9baa2b3ef0540828894dddeea3d4ed016e` |
| Linux x64 | [quantus_miner_linux.tar.gz](https://github.com/Quantus-Network/quantus-apps/releases/download/miner-v0.6.1/quantus_miner_linux.tar.gz) | `fd2755f2fe5df05af3deb8e1081fa808f6c872bd9d4bf2853eea0fe354655076` |

These URLs and hashes are also recorded in the [compatibility manifest](/mining-compatibility.json).

Verify the downloaded archive before opening it.

### Windows PowerShell

```powershell
(Get-FileHash .\quantus_miner_windows.zip -Algorithm SHA256).Hash.ToLower()
# Expected: 081308152ba6f9eba62b9ac143f8c9e115ffab400a978a9d03a996e55ece8ad1
```

### macOS Terminal

```bash
shasum -a 256 quantus_miner_macos.zip
# Expected: fb4769d4c1e8ccd3c480e0caeca07c9baa2b3ef0540828894dddeea3d4ed016e
```

### Linux Terminal

```bash
sha256sum quantus_miner_linux.tar.gz
# Expected: fd2755f2fe5df05af3deb8e1081fa808f6c872bd9d4bf2853eea0fe354655076
```

## Install

### Windows

1. Download and extract `quantus_miner_windows.zip`.
2. Open the extracted folder and run `quantus_miner.exe`.
3. If Windows Defender warns, verify the SHA-256 above before choosing to run it.

### macOS

1. Download and extract `quantus_miner_macos.zip`.
2. Open `Quantus Miner.app`.
3. If macOS blocks it, open System Settings, Privacy & Security, then choose Open Anyway.

### Linux x64

1. Download and extract `quantus_miner_linux.tar.gz`.
2. Mark `quantus_miner` executable with `chmod u+x quantus_miner`.
3. Run `./quantus_miner`.

The release does not publish minimum OS versions. The release team must supply those facts before the app can be presented as universally supported.

## What the app handles

The app downloads the node and external miner, creates the local node identity, starts both processes, monitors sync, and shows mining statistics. A recovery phrase entered into the app is handled locally by its wallet flow.

The app is ready to become the primary route after it consumes the shared compatibility manifest, verifies every runtime download, and avoids exposing reward material in logs or process arguments. Until then, use the [verified terminal guide](/guides/mining) where supported.
