---
sidebar_position: 2
title: Miner App (GUI)
draft: true
---

# Miner App

The Quantus Miner App is the easiest way to start mining. It provides a graphical interface for both CPU and GPU mining -- no terminal required.

## Download

Download the latest Miner App for your platform from [GitHub Releases](https://github.com/Quantus-Network/quantus-apps/releases/latest):

| Platform | File |
|----------|------|
| macOS (Intel / Apple Silicon) | `quantus_miner_macos.zip` |
| Linux (x64) | `quantus_miner_linux.tar.gz` |
| Windows (x64) | `quantus_miner_windows.zip` |

## Prerequisites

Before you start mining, you need:

1. A Quantus wallet address to receive rewards. Download the Quantus mobile wallet from [quantus.com/wallet](https://www.quantus.com/wallet/) and create an account.

## Installation

**macOS:** Download the `.zip` file, extract it into your desired directory, and run `Quantus Miner.app`. If macOS blocks the app, go to System Settings > Privacy & Security and click "Open Anyway."

**Linux:** Download the `.tar.gz` file, extract it into your desired directory, and run the `quantus_miner` executable.

## Note on Syncing
Once you input your inner hash (or seed phrase) you can begin syncing your node.

Wait until the node is fully synced, and then begin mining. 

Depending on your internet speed it may take 5-30 minutes for the node to full sync.

## Monitoring

Check your mining progress on the [telemetry dashboard](https://telemetry.quantus.cat/).

## Troubleshooting

| Problem | Solution |
|---------|----------|
| macOS blocks the app | System Settings > Privacy & Security > "Open Anyway" |
| App won't connect | Make sure your Quantus node is running first |
| Low hash rate | Increase CPU workers or enable GPU mining in settings |
| Mining not producing blocks | Verify your node is fully synced before mining |

## Next Steps

For advanced mining configuration (external miner, Docker, build from source), see the full [Mining and Running a Node](./mining) guide.
