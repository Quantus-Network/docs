#!/usr/bin/env bash
#
# quantus-mining.sh — Set up and manage Quantus Planck testnet mining.
#
# Supports macOS, Linux, and WSL2. Requires bash, curl, and tar.
#
# Default working directory: ~/quantus-mining/
# Config file: ~/quantus-mining/mining.conf (mode 600)
#
# Usage:
#   ./quantus-mining.sh setup [--force]
#   ./quantus-mining.sh config show|set KEY VALUE|edit
#   ./quantus-mining.sh start [-d|--detach]
#   ./quantus-mining.sh start-node|start-miner
#   ./quantus-mining.sh stop|restart [-d|--detach]
#   ./quantus-mining.sh uninstall [--force]
#   ./quantus-mining.sh help
#
# Override directory: QUANTUS_MINING_DIR=/path/to/dir ./quantus-mining.sh ...

set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly DEFAULT_MINING_DIR="${HOME}/quantus-mining"
readonly MINING_DIR="${QUANTUS_MINING_DIR:-$DEFAULT_MINING_DIR}"
readonly CONFIG_FILE="${MINING_DIR}/mining.conf"
readonly BIN_DIR="${MINING_DIR}/bin"
readonly LOG_DIR="${MINING_DIR}/logs"
readonly NODE_BIN="${BIN_DIR}/quantus-node"
readonly MINER_BIN="${BIN_DIR}/quantus-miner"
readonly NODE_PID_FILE="${MINING_DIR}/node.pid"
readonly MINER_PID_FILE="${MINING_DIR}/miner.pid"
readonly NODE_KEY_PATH="${MINING_DIR}/node_key.p2p"

readonly CHAIN_REPO="Quantus-Network/chain"
readonly MINER_REPO="Quantus-Network/quantus-miner"
readonly EDITABLE_KEYS="NODE_NAME CPU_WORKERS GPU_DEVICES MINER_LISTEN_PORT CHAIN"

OS=""
ARCH=""
NODE_TARGET=""
MINER_ASSET=""

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

die() {
  echo "Error: $*" >&2
  exit 1
}

info() {
  echo "$*"
}

warn() {
  echo "Warning: $*" >&2
}

require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || die "Required command not found: $cmd"
}

detect_platform() {
  case "$(uname -s)" in
    Linux*) OS="linux" ;;
    Darwin*) OS="macos" ;;
    *)
      die "Unsupported operating system: $(uname -s). Use macOS, Linux, or WSL2."
      ;;
  esac

  case "$(uname -m)" in
    x86_64|amd64)
      ARCH="x86_64"
      if [ "$OS" = "linux" ]; then
        NODE_TARGET="x86_64-unknown-linux-gnu"
        MINER_ASSET="quantus-miner-linux-x86_64"
      else
        NODE_TARGET="x86_64-apple-darwin"
        MINER_ASSET="quantus-miner-macos-x86_64"
      fi
      ;;
    arm64|aarch64)
      ARCH="arm64"
      if [ "$OS" = "linux" ]; then
        NODE_TARGET="aarch64-unknown-linux-gnu"
        MINER_ASSET=""
      else
        NODE_TARGET="aarch64-apple-darwin"
        MINER_ASSET="quantus-miner-macos-aarch64"
      fi
      ;;
    *)
      die "Unsupported architecture: $(uname -m)"
      ;;
  esac

  if [ "$OS" = "linux" ] && [ -z "$MINER_ASSET" ]; then
    die "No quantus-miner release for Linux ARM64. Mine from macOS or Linux x86_64 (GPU mining needs a native miner)."
  fi
}

wormhole_keygen() {
  "$NODE_BIN" key quantus --scheme wormhole "$@" 2>&1
}

ensure_dirs() {
  mkdir -p "$BIN_DIR" "$LOG_DIR"
}

fix_macos_quarantine() {
  local binary="$1"
  if [ "$OS" = "macos" ] && [ -f "$binary" ]; then
    xattr -d com.apple.quarantine "$binary" 2>/dev/null || true
  fi
}

make_executable() {
  local binary="$1"
  chmod u+x "$binary"
  fix_macos_quarantine "$binary"
}

cpu_count() {
  if command -v nproc >/dev/null 2>&1; then
    nproc
  else
    sysctl -n hw.ncpu 2>/dev/null || echo 4
  fi
}

tolower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

fetch_latest_tag() {
  local repo="$1"
  local release_json tag

  release_json="$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest")" \
    || die "Failed to fetch latest release for ${repo}"

  tag="$(printf '%s' "$release_json" | grep -o '"tag_name": "[^"]*"' | head -n 1 | cut -d'"' -f4)"
  [ -n "$tag" ] || die "Could not determine latest release tag for ${repo}"
  printf '%s' "$tag"
}

# Miner protocol this script can drive:
#   auth   = Ready { token } + TLS pin (quantus-miner/2)
#   legacy = unauthenticated Ready (pre-auth releases, e.g. node v0.9.0 / miner v3.3.1)
MINER_PROTOCOL=""

incompatible_miner_pair_die() {
  local node_auth="$1" miner_auth="$2"
  die "Incompatible node/miner pair for the miner protocol.
  Node --miner-auth-token-file: ${node_auth}
  Miner --auth-token-file / --tls-cert-sha256-file: ${miner_auth}

Do not mix a release that requires Ready { token } (quantus-miner/2) with one that does not.
GitHub latest tags are published independently — pin a matching pair:

  NODE_VERSION=<chain-tag>
  MINER_VERSION=<miner-tag>

in ${CONFIG_FILE}, or re-run setup after coordinated releases:
  https://github.com/${CHAIN_REPO}/releases
  https://github.com/${MINER_REPO}/releases"
}

classify_miner_protocol() {
  local node_help="$1" miner_help="$2"
  local node_auth="no" miner_auth="no"

  printf '%s' "$node_help" | grep -q -- 'miner-auth-token-file' && node_auth="yes"
  if printf '%s' "$miner_help" | grep -q -- 'auth-token-file' \
    && printf '%s' "$miner_help" | grep -q -- 'tls-cert-sha256-file'; then
    miner_auth="yes"
  fi

  if [ "$node_auth" = "yes" ] && [ "$miner_auth" = "yes" ]; then
    MINER_PROTOCOL="auth"
  elif [ "$node_auth" = "no" ] && [ "$miner_auth" = "no" ]; then
    MINER_PROTOCOL="legacy"
    warn "Node ${NODE_VERSION:-unknown} / miner ${MINER_VERSION:-unknown} do not include miner QUIC auth (quantus-miner/2). Starting without auth token / TLS pin."
  else
    incompatible_miner_pair_die "$node_auth" "$miner_auth"
  fi
  info "Miner protocol: ${MINER_PROTOCOL}"
}

detect_binary_miner_protocol() {
  local node_help miner_help node_status miner_status
  [ -x "$NODE_BIN" ] || die "quantus-node not found at ${NODE_BIN}"
  [ -x "$MINER_BIN" ] || die "quantus-miner not found at ${MINER_BIN}"

  node_help="$("$NODE_BIN" --help 2>&1)" && node_status=0 || node_status=$?
  if [ "$node_status" -ne 0 ]; then
    die "Failed to probe quantus-node --help (exit ${node_status}).
${node_help}"
  fi

  miner_help="$("$MINER_BIN" serve --help 2>&1)" && miner_status=0 || miner_status=$?
  if [ "$miner_status" -ne 0 ]; then
    die "Failed to probe quantus-miner serve --help (exit ${miner_status}).
${miner_help}"
  fi

  classify_miner_protocol "$node_help" "$miner_help"
}

maybe_wait_for_miner_auth_files() {
  if [ "${MINER_PROTOCOL:-}" = "auth" ]; then
    wait_for_miner_auth_files "${1:-30}"
  fi
}

download_node_binary() {
  local tag="$1"
  local asset="quantus-node-${tag}-${NODE_TARGET}.tar.gz"
  local url="https://github.com/${CHAIN_REPO}/releases/download/${tag}/${asset}"
  local temp_dir asset_path

  info "Downloading quantus-node ${tag} for ${NODE_TARGET}..."
  temp_dir="$(mktemp -d)"

  asset_path="${temp_dir}/${asset}"
  curl -fsSL "$url" -o "$asset_path" || { rm -rf "$temp_dir"; die "Failed to download ${url}"; }

  tar -xzf "$asset_path" -C "$temp_dir"
  if [ ! -f "${temp_dir}/quantus-node" ]; then
    rm -rf "$temp_dir"
    die "quantus-node not found in archive"
  fi

  cp "${temp_dir}/quantus-node" "$NODE_BIN"
  rm -rf "$temp_dir"
  make_executable "$NODE_BIN"
  info "Installed quantus-node to ${NODE_BIN}"
}

download_miner_binary() {
  local tag="$1"
  local url="https://github.com/${MINER_REPO}/releases/download/${tag}/${MINER_ASSET}"

  info "Downloading quantus-miner ${tag} (${MINER_ASSET})..."
  curl -fsSL "$url" -o "$MINER_BIN" || die "Failed to download ${url}"
  make_executable "$MINER_BIN"
  info "Installed quantus-miner to ${MINER_BIN}"
}

download_binaries() {
  local force="${1:-false}"
  local node_tag miner_tag

  if [ "$force" = "true" ] || [ ! -x "$NODE_BIN" ]; then
    node_tag="${NODE_VERSION:-}"
    [ -n "$node_tag" ] || node_tag="$(fetch_latest_tag "$CHAIN_REPO")"
    download_node_binary "$node_tag"
  else
    node_tag="${NODE_VERSION:-}"
    [ -n "$node_tag" ] || node_tag="$(grep -E '^NODE_VERSION=' "$CONFIG_FILE" 2>/dev/null | cut -d= -f2- | tr -d '"' || true)"
    [ -n "$node_tag" ] || node_tag="$(fetch_latest_tag "$CHAIN_REPO")"
    info "Using existing quantus-node at ${NODE_BIN}"
  fi

  if [ "$force" = "true" ] || [ ! -x "$MINER_BIN" ]; then
    miner_tag="${MINER_VERSION:-}"
    [ -n "$miner_tag" ] || miner_tag="$(fetch_latest_tag "$MINER_REPO")"
    download_miner_binary "$miner_tag"
  else
    miner_tag="${MINER_VERSION:-}"
    [ -n "$miner_tag" ] || miner_tag="$(grep -E '^MINER_VERSION=' "$CONFIG_FILE" 2>/dev/null | cut -d= -f2- | tr -d '"' || true)"
    [ -n "$miner_tag" ] || miner_tag="$(fetch_latest_tag "$MINER_REPO")"
    info "Using existing quantus-miner at ${MINER_BIN}"
  fi

  NODE_VERSION="$node_tag"
  MINER_VERSION="$miner_tag"
  detect_binary_miner_protocol
}

parse_wormhole_output() {
  local output="$1"
  local line

  WORMHOLE_ADDRESS="$(printf '%s\n' "$output" | grep -E '^Address:' | head -n 1 | awk '{print $2}')"
  INNER_HASH="$(printf '%s\n' "$output" | grep -E '^Inner [Hh]ash:' | head -n 1 | awk '{print $3}')"
  if [ -z "$INNER_HASH" ]; then
    INNER_HASH="$(printf '%s\n' "$output" | grep -E '^inner_hash:' | head -n 1 | awk '{print $2}')"
  fi
  WORMHOLE_SECRET=""
  line="$(printf '%s\n' "$output" | grep -E '^Secret:' | head -n 1 || true)"
  if [ -n "$line" ]; then
    WORMHOLE_SECRET="$(printf '%s' "$line" | awk '{print $2}')"
  fi

  line="$(printf '%s\n' "$output" | grep -E '^Secret phrase:' | head -n 1 || true)"
  if [ -n "$line" ]; then
    WORMHOLE_SECRET_PHRASE="${line#*Secret phrase: }"
  else
    WORMHOLE_SECRET_PHRASE=""
  fi

  [ -n "$WORMHOLE_ADDRESS" ] || die "Could not parse wormhole Address from keygen output"
  [ -n "$INNER_HASH" ] || die "Could not parse Inner Hash from keygen output"
}

generate_wormhole_keys() {
  local choice output mnemonic

  echo ""
  echo "Wormhole address generation:"
  echo "  [1] Derive from existing 24-word wallet mnemonic (recommended)"
  echo "  [2] Generate a fresh keypair"
  read -r -p "Enter choice (1/2) [1]: " choice
  choice="${choice:-1}"

  case "$choice" in
    1)
      echo "Enter your 24-word mnemonic (input hidden):"
      read -r -s mnemonic
      echo ""
      [ -n "$mnemonic" ] || die "Mnemonic cannot be empty"
      output="$(printf '%s\n' "$mnemonic" | wormhole_keygen --words)"
      ;;
    2)
      output="$(wormhole_keygen)"
      ;;
    *)
      die "Invalid choice: $choice"
      ;;
  esac

  parse_wormhole_output "$output"

  echo ""
  echo "Wormhole keypair generated. Save these values securely:"
  echo "$output"
  echo ""
  warn "Back up your 24-word seed phrase. Loss means loss of mining rewards."
}

prompt_resource_allocation() {
  local cores has_gpu choice default_workers

  cores="$(cpu_count)"
  echo ""
  echo "This machine has ${cores} CPU cores."
  echo "GPU mining is strongly recommended (~500-1000 MH/s vs ~15 MH/s per CPU worker)."
  read -r -p "Do you have a GPU available for mining? (y/N): " has_gpu

  case "$(tolower "$has_gpu")" in
    y|yes)
      GPU_DEVICES=1
      CPU_WORKERS=0
      info "Default: GPU mining with --gpu-devices 1 --cpu-workers 0"
      ;;
    *)
      default_workers=$((cores - 2))
      [ "$default_workers" -lt 1 ] && default_workers=1
      GPU_DEVICES=0
      CPU_WORKERS="$default_workers"
      info "Default: CPU-only mining with --cpu-workers ${CPU_WORKERS} (leaving 2 cores for OS/node)"
      ;;
  esac

  read -r -p "CPU workers [${CPU_WORKERS}]: " choice
  if [ -n "$choice" ]; then
    CPU_WORKERS="$choice"
  fi

  read -r -p "GPU devices [${GPU_DEVICES}]: " choice
  if [ -n "$choice" ]; then
    GPU_DEVICES="$choice"
  fi
}

write_config() {
  CHAIN="${CHAIN:-planck}"
  MINER_LISTEN_PORT="${MINER_LISTEN_PORT:-9833}"
  CPU_WORKERS="${CPU_WORKERS:-0}"
  GPU_DEVICES="${GPU_DEVICES:-0}"

  cat > "$CONFIG_FILE" <<EOF
# Quantus mining configuration — ${CONFIG_FILE}
# Generated by ${SCRIPT_NAME} setup

RUN_MODE="binary"
NODE_NAME="${NODE_NAME}"
INNER_HASH="${INNER_HASH}"
WORMHOLE_ADDRESS="${WORMHOLE_ADDRESS}"
NODE_KEY_FILE="node_key.p2p"
CHAIN="${CHAIN}"
MINER_LISTEN_PORT=${MINER_LISTEN_PORT}
CPU_WORKERS=${CPU_WORKERS}
GPU_DEVICES=${GPU_DEVICES}
NODE_VERSION="${NODE_VERSION}"
MINER_VERSION="${MINER_VERSION}"
MINER_PROTOCOL="${MINER_PROTOCOL:-}"
EOF
  chmod 600 "$CONFIG_FILE"
  info "Wrote config to ${CONFIG_FILE}"
}

load_config() {
  [ -f "$CONFIG_FILE" ] || die "Config not found at ${CONFIG_FILE}. Run: ${SCRIPT_NAME} setup"
  # shellcheck source=/dev/null
  source "$CONFIG_FILE"

  RUN_MODE="${RUN_MODE:-binary}"
  if [ "$RUN_MODE" = "docker" ]; then
    die "Docker mining is no longer supported. Re-run: ${SCRIPT_NAME} setup --force"
  fi
  : "${NODE_NAME:?NODE_NAME missing in config}"
  : "${INNER_HASH:?INNER_HASH missing in config}"
  NODE_KEY_FILE="${NODE_KEY_FILE:-node_key.p2p}"
  CHAIN="${CHAIN:-planck}"
  MINER_LISTEN_PORT="${MINER_LISTEN_PORT:-9833}"
  CPU_WORKERS="${CPU_WORKERS:-0}"
  GPU_DEVICES="${GPU_DEVICES:-0}"
}

process_alive() {
  local pid="$1"
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

read_pid_file() {
  local file="$1"
  if [ -f "$file" ]; then
    tr -d '[:space:]' < "$file"
  fi
}

stop_pid() {
  local pid="$1"
  local name="$2"
  local pattern="${3:-}"

  [ -n "$pid" ] || return 1
  process_alive "$pid" || return 1

  if [ -n "$pattern" ]; then
    ps -p "$pid" -o command= 2>/dev/null | grep -qF "$pattern" || return 1
  fi

  info "Stopping ${name} (PID ${pid})..."
  kill "$pid" 2>/dev/null || true
  local i
  for i in $(seq 1 15); do
    process_alive "$pid" || return 0
    sleep 1
  done

  if process_alive "$pid"; then
    warn "${name} did not exit gracefully; sending SIGKILL"
    kill -9 "$pid" 2>/dev/null || true
  fi
  return 0
}

stop_from_pid_file() {
  local name="$1"
  local pid_file="$2"
  local pattern="$3"
  local pid stopped=false

  pid="$(read_pid_file "$pid_file")"
  if [ -n "$pid" ] && stop_pid "$pid" "$name" "$pattern"; then
    stopped=true
  fi
  rm -f "$pid_file"
  [ "$stopped" = true ]
}

find_pids_for_binary() {
  local binary="$1"
  local pid

  if command -v pgrep >/dev/null 2>&1; then
    pgrep -f "$binary" 2>/dev/null || true
    return 0
  fi

  ps -ax -o pid=,command= 2>/dev/null | while IFS= read -r line; do
    case "$line" in
      *"$binary"*)
        pid="${line%% *}"
        [ -n "$pid" ] && echo "$pid"
        ;;
    esac
  done
}

stop_binary_processes() {
  local binary="$1"
  local label="$2"
  local pid stopped=false

  [ -x "$binary" ] || return 1

  while IFS= read -r pid; do
    [ -n "$pid" ] || continue
    if stop_pid "$pid" "$label" "$binary"; then
      stopped=true
    fi
  done < <(find_pids_for_binary "$binary" | sort -u)

  [ "$stopped" = true ]
}

stop_log_tail_helpers() {
  local pid stopped=false

  if ! command -v pgrep >/dev/null 2>&1; then
    return 1
  fi

  while IFS= read -r pid; do
    [ -n "$pid" ] || continue
    if stop_pid "$pid" "log tail helper" "tail"; then
      stopped=true
    fi
  done < <(pgrep -f "${LOG_DIR}/node.log" 2>/dev/null || true)

  [ "$stopped" = true ]
}

write_pid_file() {
  local pid_file="$1"
  local pid="$2"
  echo "$pid" > "$pid_file"
}

clear_pid_files() {
  rm -f "$NODE_PID_FILE" "$MINER_PID_FILE"
}

port_listening() {
  local port="$1"
  # Miner protocol is QUIC (UDP). Also check TCP for compatibility.
  if command -v lsof >/dev/null 2>&1; then
    lsof -iTCP:"${port}" -sTCP:LISTEN -P -n >/dev/null 2>&1 && return 0
    lsof -iUDP:"${port}" -P -n >/dev/null 2>&1 && return 0
  fi
  if command -v ss >/dev/null 2>&1; then
    ss -ltn 2>/dev/null | grep -q ":${port} " && return 0
    ss -lun 2>/dev/null | grep -q ":${port} " && return 0
  fi
  if command -v netstat >/dev/null 2>&1; then
    netstat -an 2>/dev/null | grep -q "\.${port} .*LISTEN" && return 0
    netstat -an 2>/dev/null | grep -qi "\.${port} .*udp" && return 0
  fi
  return 1
}

# Substrate default data dir for quantus-node (chain-scoped files live under chains/<chain>/).
node_data_path() {
  if [ -n "${QUANTUS_NODE_DATA_PATH:-}" ]; then
    printf '%s' "$QUANTUS_NODE_DATA_PATH"
    return
  fi
  case "$(uname -s)" in
    Darwin)
      printf '%s/Library/Application Support/quantus-node' "$HOME"
      ;;
    *)
      printf '%s/quantus-node' "${XDG_DATA_HOME:-$HOME/.local/share}"
      ;;
  esac
}

node_chain_dir() {
  printf '%s/chains/%s' "$(node_data_path)" "${CHAIN:-planck}"
}

miner_auth_token_path() {
  printf '%s/miner-auth-token' "$(node_chain_dir)"
}

miner_tls_pin_path() {
  printf '%s/miner-tls-cert-sha256' "$(node_chain_dir)"
}

wait_for_miner_auth_files() {
  local token_file pin_file timeout="${1:-120}" i
  token_file="$(miner_auth_token_path)"
  pin_file="$(miner_tls_pin_path)"

  info "Waiting for miner auth files (up to ${timeout}s)..."
  for i in $(seq 1 "$timeout"); do
    if [ -s "$token_file" ] && [ -s "$pin_file" ]; then
      return 0
    fi
    sleep 1
  done

  die "Timed out waiting for miner auth files:
  ${token_file}
  ${pin_file}
Start the node first and wait until it is listening."
}

wait_for_miner_server() {
  local port="$1"
  local log_file="${2:-}"
  local timeout="${3:-120}"
  local i

  info "Waiting for miner server on port ${port} (up to ${timeout}s)..."
  for i in $(seq 1 "$timeout"); do
    if [ -n "$log_file" ] && [ -f "$log_file" ] && grep -qi "miner server listening" "$log_file" 2>/dev/null; then
      return 0
    fi
    if port_listening "$port"; then
      return 0
    fi
    sleep 1
  done

  if [ -n "$log_file" ]; then
    die "Timed out waiting for miner server on port ${port}. Check ${log_file}"
  fi
  die "Timed out waiting for miner server on port ${port}."
}

detect_run_mode() {
  RUN_MODE="binary"
  if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
    RUN_MODE="${RUN_MODE:-binary}"
  fi
}

mining_stack_running() {
  local node_pid miner_pid

  detect_run_mode

  node_pid="$(read_pid_file "$NODE_PID_FILE")"
  miner_pid="$(read_pid_file "$MINER_PID_FILE")"
  if process_alive "$node_pid" || process_alive "$miner_pid"; then
    return 0
  fi
  if port_listening "${MINER_LISTEN_PORT:-9833}"; then
    return 0
  fi
  return 1
}

parse_detach_flag() {
  DETACH="false"
  while [ $# -gt 0 ]; do
    case "$1" in
      -d|--detach) DETACH="true" ;;
      *) die "Unknown option: $1 (use -d or --detach to run in background)" ;;
    esac
    shift
  done
}

mask_hash() {
  local hash="$1"
  local len="${#hash}"
  if [ "$len" -le 12 ]; then
    echo "****"
  else
    echo "${hash:0:6}...${hash: -6}"
  fi
}

validate_editable_key() {
  local key="$1"
  case " ${EDITABLE_KEYS} " in
    *" ${key} "*) return 0 ;;
    *) return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

cmd_help() {
  cat <<EOF
${SCRIPT_NAME} — Set up and manage Quantus Planck testnet mining.

Working directory: ${MINING_DIR}
Config file:       ${CONFIG_FILE}

Commands:
  setup [--force]           Interactive setup: download binaries, generate keys, write config
  config show               Show current config (inner hash masked)
  config set KEY VALUE      Update an editable config key
  config edit               Open config in \$EDITOR
  start [-d|--detach]       Start node + miner
  start-node                Start only the node (foreground)
  start-miner               Start only the miner (node must already be running)
  stop                      Stop node, miner, and related helper processes
  restart [-d|--detach]     Stop then start
  uninstall [--force]       Stop processes and remove ${MINING_DIR} (config, keys, binaries, logs)
  help                      Show this help

Editable config keys: ${EDITABLE_KEYS}

Environment:
  QUANTUS_MINING_DIR        Override default working directory (${DEFAULT_MINING_DIR})
  QUANTUS_NODE_DATA_PATH    Override node data directory (default: Substrate quantus-node path)
  NODE_VERSION / MINER_VERSION
                            Pin a matching node/miner release pair (do not mix independent latest tags)
EOF
}

cmd_setup() {
  local force="false"

  while [ $# -gt 0 ]; do
    case "$1" in
      --force) force="true" ;;
      --mode)
        shift
        [ $# -gt 0 ] || die "Missing value for --mode"
        case "$1" in
          docker) die "Docker mining is no longer supported. Use native binaries (GPU mining needs a host miner)." ;;
          binary) ;;
          *) die "Unknown setup mode: $1" ;;
        esac
        ;;
      *) die "Unknown setup option: $1" ;;
    esac
    shift
  done

  require_cmd curl
  require_cmd tar

  RUN_MODE="binary"
  detect_platform
  ensure_dirs

  info "Platform: ${OS} / ${ARCH} (${NODE_TARGET})"
  info "Working directory: ${MINING_DIR}"

  if [ -f "$CONFIG_FILE" ] && [ "$force" != "true" ]; then
    warn "Config already exists at ${CONFIG_FILE}"
    read -r -p "Overwrite existing setup? (y/N): " confirm
    case "$(tolower "$confirm")" in
      y|yes) ;;
      *) info "Setup cancelled."; return 0 ;;
    esac
  fi

  download_binaries "$force"

  if [ ! -f "$NODE_KEY_PATH" ]; then
    info "Generating node P2P identity..."
    "$NODE_BIN" key generate-node-key --file "$NODE_KEY_PATH"
  else
    info "Using existing node key at ${NODE_KEY_PATH}"
  fi

  read -r -p "Enter a node name (shown on telemetry): " NODE_NAME
  [ -n "$NODE_NAME" ] || die "Node name cannot be empty"

  generate_wormhole_keys
  prompt_resource_allocation
  write_config

  echo ""
  info "Setup complete."
  info "Start mining with: ${SCRIPT_NAME} start"
  info "Telemetry dashboard: https://telemetry.quantus.cat/"
}

cmd_config() {
  local sub="${1:-}"
  shift || true

  case "$sub" in
    show)
      [ -f "$CONFIG_FILE" ] || die "Config not found. Run: ${SCRIPT_NAME} setup"
      while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
          \#*|"") echo "$line" ;;
          INNER_HASH=*)
            local val="${line#INNER_HASH=}"
            val="${val#\"}"; val="${val%\"}"
            echo "INNER_HASH=\"$(mask_hash "$val")\""
            ;;
          *) echo "$line" ;;
        esac
      done < "$CONFIG_FILE"
      ;;
    set)
      local key="${1:-}" value="${2:-}"
      [ -n "$key" ] && [ -n "$value" ] || die "Usage: ${SCRIPT_NAME} config set KEY VALUE"
      validate_editable_key "$key" || die "Key not editable via 'set': ${key}. Editable: ${EDITABLE_KEYS}"
      [ -f "$CONFIG_FILE" ] || die "Config not found. Run: ${SCRIPT_NAME} setup"

      load_config
      case "$key" in
        NODE_NAME) NODE_NAME="$value" ;;
        CPU_WORKERS) CPU_WORKERS="$value" ;;
        GPU_DEVICES) GPU_DEVICES="$value" ;;
        MINER_LISTEN_PORT) MINER_LISTEN_PORT="$value" ;;
        CHAIN) CHAIN="$value" ;;
      esac
      write_config
      info "Updated ${key}=${value}"
      ;;
    edit)
      [ -f "$CONFIG_FILE" ] || die "Config not found. Run: ${SCRIPT_NAME} setup"
      local editor="${EDITOR:-vi}"
      "$editor" "$CONFIG_FILE"
      load_config
      info "Config reloaded."
      ;;
    *)
      die "Usage: ${SCRIPT_NAME} config show|set KEY VALUE|edit"
      ;;
  esac
}

ensure_start_prerequisites() {
  load_config
  ensure_dirs

  detect_platform
  [ -x "$NODE_BIN" ] || die "quantus-node not found at ${NODE_BIN}. Run: ${SCRIPT_NAME} setup"
  [ -x "$MINER_BIN" ] || die "quantus-miner not found at ${MINER_BIN}. Run: ${SCRIPT_NAME} setup"

  START_NODE_KEY="${MINING_DIR}/${NODE_KEY_FILE}"
  [ -f "$START_NODE_KEY" ] || die "Node key not found at ${START_NODE_KEY}. Run: ${SCRIPT_NAME} setup"
  detect_binary_miner_protocol
}

run_quantus_node() {
  "$NODE_BIN" \
    --name "$NODE_NAME" \
    --validator \
    --miner-listen-port "$MINER_LISTEN_PORT" \
    --chain "$CHAIN" \
    --node-key-file "$START_NODE_KEY" \
    --rewards-inner-hash "$INNER_HASH" \
    --max-blocks-per-request 64 \
    --sync full
}

run_quantus_miner() {
  local token_file pin_file

  if [ "${MINER_PROTOCOL:-}" != "auth" ]; then
    "$MINER_BIN" serve \
      --cpu-workers "$CPU_WORKERS" \
      --gpu-devices "$GPU_DEVICES" \
      --node-addr "127.0.0.1:${MINER_LISTEN_PORT}"
    return
  fi

  token_file="$(miner_auth_token_path)"
  pin_file="$(miner_tls_pin_path)"
  [ -s "$token_file" ] || die "Miner auth token not found at ${token_file}. Start the node first and wait until it is listening."
  [ -s "$pin_file" ] || die "Miner TLS pin not found at ${pin_file}. Start the node first and wait until it is listening."

  "$MINER_BIN" serve \
    --cpu-workers "$CPU_WORKERS" \
    --gpu-devices "$GPU_DEVICES" \
    --node-addr "127.0.0.1:${MINER_LISTEN_PORT}" \
    --auth-token-file "$token_file" \
    --tls-cert-sha256-file "$pin_file"
}

start_miner_background() {
  local miner_log="$1"

  info "Starting quantus-miner in background (log: ${miner_log})..."
  run_quantus_miner >> "$miner_log" 2>&1 &
  MINER_BG_PID=$!
  sleep 1
  if ! process_alive "$MINER_BG_PID"; then
    warn "Last lines from ${miner_log}:"
    tail -n 10 "$miner_log" 2>/dev/null >&2 || true
    die "Miner exited immediately. Check ${miner_log}"
  fi
  info "Miner started (PID ${MINER_BG_PID})."
}

stop_foreground_stack() {
  local node_pid="${1:-}"
  local miner_pid="${2:-}"
  local tail_pid="${3:-}"

  # Miner first, then node (matches cmd_stop).
  [ -n "$tail_pid" ] && stop_pid "$tail_pid" "log tail" "tail" || true
  if [ -n "$miner_pid" ]; then
    stop_pid "$miner_pid" "quantus-miner" "$MINER_BIN" || true
  fi
  stop_from_pid_file "quantus-miner" "$MINER_PID_FILE" "$MINER_BIN" || true
  stop_binary_processes "$MINER_BIN" "quantus-miner" || true
  if [ -n "$node_pid" ]; then
    stop_pid "$node_pid" "quantus-node" "$NODE_BIN" || true
  fi
  stop_from_pid_file "quantus-node" "$NODE_PID_FILE" "$NODE_BIN" || true
  stop_binary_processes "$NODE_BIN" "quantus-node" || true
  clear_pid_files
}

cmd_start_node() {
  ensure_start_prerequisites

  if mining_stack_running; then
    die "Node already running on port ${MINER_LISTEN_PORT}. Use ${SCRIPT_NAME} start-miner in another terminal."
  fi

  info "Starting quantus-node in foreground."
  info "When the node logs show the miner server is listening, open another terminal and run:"
  info "  ${SCRIPT_NAME} start-miner"
  echo ""
  run_quantus_node
}

cmd_start_miner() {
  ensure_start_prerequisites

  if ! port_listening "$MINER_LISTEN_PORT"; then
    die "Node miner server is not listening on port ${MINER_LISTEN_PORT}. Start the node first: ${SCRIPT_NAME} start-node"
  fi

  info "Starting quantus-miner in foreground (hash rate output below)."
  run_quantus_miner
}

cmd_start() {
  local node_log miner_log
  local node_pid="" miner_pid="" tail_pid=""

  parse_detach_flag "$@"

  ensure_start_prerequisites

  if mining_stack_running; then
    die "Mining stack already running. Run: ${SCRIPT_NAME} stop (if detached) or stop the running processes"
  fi

  node_log="${LOG_DIR}/node.log"
  miner_log="${LOG_DIR}/miner.log"

  if [ "$DETACH" = "true" ]; then
    info "Starting quantus-node in background..."
    nohup "$NODE_BIN" \
      --name "$NODE_NAME" \
      --validator \
      --miner-listen-port "$MINER_LISTEN_PORT" \
      --chain "$CHAIN" \
      --node-key-file "$START_NODE_KEY" \
      --rewards-inner-hash "$INNER_HASH" \
      --max-blocks-per-request 64 \
      --sync full \
      >> "$node_log" 2>&1 &
    echo $! > "$NODE_PID_FILE"
    info "Node started (PID $(cat "$NODE_PID_FILE")). Log: ${node_log}"

    wait_for_miner_server "$MINER_LISTEN_PORT" "$node_log" 120
    maybe_wait_for_miner_auth_files 30

    start_miner_background "$miner_log"
    echo $MINER_BG_PID > "$MINER_PID_FILE"

    echo ""
    info "Mining stack running in background."
    info "Wait for full sync before expecting blocks (check ${node_log})."
    info "Telemetry: https://telemetry.quantus.cat/ (search for '${NODE_NAME}')"
    info "Stop with: ${SCRIPT_NAME} stop"
    return 0
  fi

  info "Starting quantus-node in foreground with quantus-miner in background."
  info "Node output appears below. Miner logs: ${miner_log}"
  info "For two terminals, use: ${SCRIPT_NAME} start-node  then  ${SCRIPT_NAME} start-miner"
  info "Press Ctrl+C to stop both."
  info "Telemetry: https://telemetry.quantus.cat/ (search for '${NODE_NAME}')"
  echo ""

  cleanup_foreground() {
    trap - INT TERM
    set +m 2>/dev/null || true
    info "Stopping mining stack..."
    stop_foreground_stack "$node_pid" "$miner_pid" "$tail_pid"
    exit 130
  }
  trap cleanup_foreground INT TERM

  # Put background jobs in their own process groups so Ctrl+C hits this
  # shell (and the trap) instead of killing the node directly.
  set -m

  info "Starting quantus-node..."
  : > "$node_log"
  run_quantus_node >> "$node_log" 2>&1 &
  node_pid=$!
  write_pid_file "$NODE_PID_FILE" "$node_pid"

  tail -n +1 -f "$node_log" &
  tail_pid=$!

  wait_for_miner_server "$MINER_LISTEN_PORT" "$node_log" 120
  maybe_wait_for_miner_auth_files 30

  start_miner_background "$miner_log"
  miner_pid=$MINER_BG_PID
  write_pid_file "$MINER_PID_FILE" "$miner_pid"

  info "Wait for full sync before expecting blocks."
  wait "$node_pid" || true
  trap - INT TERM
  set +m 2>/dev/null || true
  stop_foreground_stack "$node_pid" "$miner_pid" "$tail_pid"
}

cmd_stop() {
  local stopped=false

  detect_run_mode
  MINER_LISTEN_PORT="${MINER_LISTEN_PORT:-9833}"

  # Miner first, then node.
  if stop_from_pid_file "quantus-miner" "$MINER_PID_FILE" "$MINER_BIN"; then
    stopped=true
  fi
  if stop_binary_processes "$MINER_BIN" "quantus-miner"; then
    stopped=true
  fi

  if stop_from_pid_file "quantus-node" "$NODE_PID_FILE" "$NODE_BIN"; then
    stopped=true
  fi
  if stop_binary_processes "$NODE_BIN" "quantus-node"; then
    stopped=true
  fi

  if stop_log_tail_helpers; then
    stopped=true
  fi

  clear_pid_files

  if [ "$stopped" = true ]; then
    info "Mining stack stopped."
  else
    warn "No running quantus-node or quantus-miner processes found under ${MINING_DIR}."
  fi
}

cmd_restart() {
  cmd_stop
  cmd_start "$@"
}

cmd_uninstall() {
  local force="false"
  local chain_data="${HOME}/.local/share/quantus-node"

  while [ $# -gt 0 ]; do
    case "$1" in
      --force|-f|--yes|-y) force="true" ;;
      *) die "Unknown uninstall option: $1 (use --force to skip confirmation)" ;;
    esac
    shift
  done

  if [ ! -e "$MINING_DIR" ] && ! mining_stack_running; then
    warn "Nothing to uninstall at ${MINING_DIR}."
    return 0
  fi

  if [ "$force" != "true" ]; then
    echo ""
    warn "This permanently removes ${MINING_DIR}, including:"
    echo "  - mining.conf (inner hash and wormhole address)"
    echo "  - node_key.p2p"
    echo "  - downloaded binaries and logs"
    echo ""
    warn "Ensure your 24-word seed phrase is backed up before continuing."
    read -r -p "Uninstall Quantus mining setup? (y/N): " confirm
    case "$(tolower "$confirm")" in
      y|yes) ;;
      *) info "Uninstall cancelled."; return 0 ;;
    esac
  fi

  cmd_stop || true

  if [ -e "$MINING_DIR" ]; then
    info "Removing ${MINING_DIR}..."
    rm -rf "$MINING_DIR"
  fi

  info "Uninstall complete."

  if [ -d "$chain_data" ]; then
    info "Chain sync data was not removed: ${chain_data}"
    info "Delete it manually to reclaim disk space."
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
  local cmd="${1:-help}"
  shift || true

  case "$cmd" in
    setup) cmd_setup "$@" ;;
    config) cmd_config "$@" ;;
    start) cmd_start "$@" ;;
    start-node) cmd_start_node "$@" ;;
    start-miner) cmd_start_miner "$@" ;;
    stop) cmd_stop "$@" ;;
    restart) cmd_restart "$@" ;;
    uninstall) cmd_uninstall "$@" ;;
    help|-h|--help) cmd_help ;;
    *) die "Unknown command: ${cmd}. Run: ${SCRIPT_NAME} help" ;;
  esac
}

main "$@"
