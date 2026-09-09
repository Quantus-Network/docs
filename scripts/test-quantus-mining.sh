#!/usr/bin/env bash
# Regression tests for quantus-mining.sh identity preservation.
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

write_existing_config() {
  cat > "$CONFIG_FILE" <<EOF
RUN_MODE="binary"
NODE_NAME="${PRESERVED_NAME}"
INNER_HASH="${PRESERVED_HASH}"
WORMHOLE_ADDRESS="${PRESERVED_ADDRESS}"
NODE_KEY_FILE="node_key.p2p"
CHAIN="mainnet"
MINER_LISTEN_PORT=9833
CPU_WORKERS=4
GPU_DEVICES=1
NODE_VERSION="v0.9.0"
MINER_VERSION="v3.3.1"
MINER_PROTOCOL="auth"
EOF
  chmod 600 "$CONFIG_FILE"
  mkdir -p "$BIN_DIR"
  : > "$NODE_KEY_PATH"
}

download_binaries() {
  NODE_VERSION="v1.0.1"
  MINER_VERSION="v4.1.0"
  MINER_PROTOCOL="auth"
}

detect_platform() {
  OS="linux"
  ARCH="x86_64"
  NODE_TARGET="x86_64-unknown-linux-gnu"
}

generate_wormhole_keys() {
  fail "generate_wormhole_keys must not run when refreshing an existing identity"
}

prompt_resource_allocation() {
  fail "prompt_resource_allocation must not run when refreshing an existing identity"
}

write_existing_config
cmd_setup --force

# shellcheck source=/dev/null
source "$CONFIG_FILE"
assert_eq "INNER_HASH" "$PRESERVED_HASH" "$INNER_HASH"
assert_eq "WORMHOLE_ADDRESS" "$PRESERVED_ADDRESS" "$WORMHOLE_ADDRESS"
assert_eq "NODE_NAME" "$PRESERVED_NAME" "$NODE_NAME"
assert_eq "CPU_WORKERS" "4" "$CPU_WORKERS"
assert_eq "GPU_DEVICES" "1" "$GPU_DEVICES"
assert_eq "CHAIN" "mainnet" "$CHAIN"
assert_eq "NODE_VERSION" "v1.0.1" "$NODE_VERSION"
assert_eq "MINER_VERSION" "v4.1.0" "$MINER_VERSION"

echo "ok: setup --force preserves existing reward identity"
