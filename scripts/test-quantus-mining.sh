#!/usr/bin/env bash
# Regression test: setup --force keeps an existing install's reward identity.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export QUANTUS_MINING_DIR
QUANTUS_MINING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/quantus-mining-test.XXXXXX")"
trap 'rm -rf "$QUANTUS_MINING_DIR"' EXIT

# shellcheck source=../static/scripts/quantus-mining.sh
source "$ROOT/static/scripts/quantus-mining.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  [ "$expected" = "$actual" ] || fail "${label}: expected '${expected}', got '${actual}'"
}

PRESERVED_HASH="0xabc123def456abc123def456abc123def456abc123def456abc123def456abcd"
PRESERVED_ADDRESS="qzExistingRewardAddress"
PRESERVED_NAME="old-planck-node"

# A Planck-era install: old pair, old chain, preimage in its owner-only file.
write_existing_install() {
  mkdir -p "$BIN_DIR" "$LOG_DIR"
  cat > "$CONFIG_FILE" <<EOF
RUN_MODE="binary"
NODE_NAME="${PRESERVED_NAME}"
WORMHOLE_ADDRESS="${PRESERVED_ADDRESS}"
NODE_KEY_FILE="node_key.p2p"
CHAIN="planck"
MINER_LISTEN_PORT=9833
CPU_WORKERS=4
GPU_DEVICES=1
NODE_VERSION="v0.10.0"
MINER_VERSION="v4.0.2"
MINER_PROTOCOL="auth"
EOF
  chmod 600 "$CONFIG_FILE"
  printf '%s\n' "$PRESERVED_HASH" > "$INNER_HASH_FILE"
  chmod 600 "$INNER_HASH_FILE"
  : > "$NODE_KEY_PATH"
}

require_cmd() { :; }

detect_platform() {
  OS="linux"
  ARCH="x86_64"
  PLATFORM_KEY="LinuxX8664"
  NODE_TARGET="x86_64-unknown-linux-gnu"
  MINER_ASSET="quantus-miner-linux-x86_64"
}

# Stand-in for the verified download: sets what fetching the manifest sets.
download_binaries() {
  CHAIN="mainnet"
  NODE_VERSION="v1.0.1"
  MINER_VERSION="v4.2.0"
  MINER_PROTOCOL="auth"
}

generate_wormhole_keys() {
  fail "generate_wormhole_keys must not run when refreshing an existing identity"
}

configure_resource_defaults() {
  fail "configure_resource_defaults must not run when refreshing an existing identity"
}

write_existing_install
cmd_setup --force >/dev/null

# shellcheck source=/dev/null
source "$CONFIG_FILE"
assert_eq "rewards-inner-hash" "$PRESERVED_HASH" "$(tr -d '[:space:]' < "$INNER_HASH_FILE")"
assert_eq "WORMHOLE_ADDRESS" "$PRESERVED_ADDRESS" "$WORMHOLE_ADDRESS"
assert_eq "NODE_NAME" "$PRESERVED_NAME" "$NODE_NAME"
assert_eq "CPU_WORKERS" "4" "$CPU_WORKERS"
assert_eq "GPU_DEVICES" "1" "$GPU_DEVICES"
assert_eq "CHAIN" "mainnet" "$CHAIN"
assert_eq "NODE_VERSION" "v1.0.1" "$NODE_VERSION"
assert_eq "MINER_VERSION" "v4.2.0" "$MINER_VERSION"
grep -q "INNER_HASH" "$CONFIG_FILE" && fail "the preimage must not be written into the public config"

echo "ok: setup --force preserves existing reward identity"
