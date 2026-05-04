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

## Installation

**macOS:** Download the `.zip` file, extract it, and run `Quantus Miner.app`. If macOS blocks the app, go to System Settings > Privacy & Security and click "Open Anyway."

**Linux:** Download the `.tar.gz` file, extract it, and run the `quantus_miner` executable.

**Windows:** Download the `.zip` file, extract it, and run `quantus_miner.exe`.

## Prerequisites

Before you start mining, you need:

1. A Quantus wallet address to receive rewards. Download the Quantus mobile wallet from [linktr.ee/quantusnetwork](https://linktr.ee/quantusnetwork) and create an account.
2. A running Quantus node. See [Mining and Running a Node](./mining) for node setup.

The Miner App handles the mining computation, but it connects to your local node (which handles the blockchain networking and block submission).

## Features

- CPU and GPU mining support
- Real-time hash rate display
- Configure number of CPU workers and GPU devices
- Simple start/stop controls

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
