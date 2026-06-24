#!/bin/sh
# Generates the libp2p node identity on first start, then execs quantus-node.
# Mounted into the quantus-node container by docker-compose.yml.

set -e

NODE_KEY_DIR="/node-keys"
NODE_KEY_FILE="${NODE_KEY_DIR}/key_node"

if [ ! -f "$NODE_KEY_FILE" ]; then
  echo "Generating node key..."
  mkdir -p "$NODE_KEY_DIR"
  /usr/local/bin/quantus-node key generate-node-key --file "$NODE_KEY_FILE"
  echo "Node key generated at: ${NODE_KEY_FILE}"
fi

exec /usr/local/bin/quantus-node "$@"
