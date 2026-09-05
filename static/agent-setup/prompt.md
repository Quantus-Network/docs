# Set up Quantus mining

Help the user set up Planck testnet mining on this computer. Complete ordinary
setup work with your tools, but pause for private wallet input. Planck tokens
have no monetary value and the network may reset. This is not a mainnet setup.

## Read before running

Fetch these resources from docs.quantus.com:

- https://docs.quantus.com/skills/mining-skill.md
- https://docs.quantus.com/mining-compatibility.json
- https://docs.quantus.com/guides/mining/

If a resource is missing, returns an HTML error instead of the expected content,
or disagrees with the others, stop and report the exact blocker. Do not invent
commands or substitute a third-party installer. The compatibility manifest is
the source for the supported node/miner pair; never choose independent latest
versions. Read its linked release evidence before installing.

## Preflight

1. Detect OS and architecture, free disk space and available CPU/GPU resources.
   Use native PowerShell on Windows x64, or the Unix installer on a platform
   listed by the guide and manifest. Do not silently install WSL, buy a VPS or
   assume phone support. Report unpublished minimum requirements as unknown.
2. Check whether a Quantus setup already exists without reading its secrets.
   Preserve existing wallets, configuration and chain data. Do not overwrite or
   force-reinstall a working setup without explaining why and asking first.
3. Explain that mining consumes power, storage and compute, and sync can take
   time. Use conservative resource settings. Ask before starting a paid cloud
   instance or changing firewall, antivirus, privileges or startup services.
   Never add antivirus exclusions as an automatic troubleshooting step.

## Install and start

Download the matching installer and its published SHA-256 file to a local setup
directory. Verify the bytes before execution and inspect the script. Never pipe
remote code into a shell. A checksum served beside a script checks integrity,
not an independent signature or proof that the code is safe.

- Windows: https://docs.quantus.com/scripts/quantus-mining.ps1
- Unix: https://docs.quantus.com/scripts/quantus-mining.sh
- Append `.sha256` to the chosen URL for the checksum file.

Use the guide's verified command block and the installer's `mine` command. The
installer must validate release downloads against the pinned manifest. Do not
disable verification, supply version overrides or change networks.

Never ask for or capture a recovery phrase, private key, reward preimage, auth
token or TLS key in chat, command arguments, logs, screenshots or repositories.
Before any wallet prompt, hand control to the user in an unrecorded local
terminal and stop reading it. If your tools cannot provide a private terminal,
prepare the files and ask the user to perform that step locally. Do not run the
interactive wallet step in an agent-captured terminal. Resume only after the
user confirms completion. Do not inspect wallet or credential files.

Keep miner control, RPC and metrics private. Do not expose ports 9833/UDP, 9944
or 9615. Only the documented peer-to-peer service may be public.

## Verify, do not assume

Use the chosen installer's `status` command. A running process alone is not
success. Distinguish installed, syncing, connected and actively mining states.
Require a synced node, live miner work and a current nonzero hash rate before
reporting mining success. Then run `restart-check` and confirm recovery.

If sync is unfinished, report "installed, syncing" and the next status command,
not "mining complete". If a check fails, give one specific next action. Do not
automatically weaken security or repeatedly reinstall to hide a failure.

Finish with non-secret facts: platform, network, pinned versions, sync state,
mining state, hash rate and restart result. Include the local `status` and `stop`
commands for the actual shell. Never paste raw logs or promise earnings, a
launch date, instant sync or a leaderboard position.
