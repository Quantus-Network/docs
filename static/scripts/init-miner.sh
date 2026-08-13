#!/bin/sh
# Wait for the node to write miner auth files, then exec quantus-miner.
# Mounted into the quantus-miner container by docker-compose.yml.

set -e

CHAIN="${CHAIN:-planck}"
TOKEN_FILE="${MINER_AUTH_TOKEN_FILE:-/node-data/chains/${CHAIN}/miner-auth-token}"
PIN_FILE="${MINER_TLS_CERT_SHA256_FILE:-/node-data/chains/${CHAIN}/miner-tls-cert-sha256}"

echo "Waiting for miner auth files from the node..."
i=0
while [ ! -s "$TOKEN_FILE" ] || [ ! -s "$PIN_FILE" ]; do
  i=$((i + 1))
  if [ "$i" -gt 120 ]; then
    echo "Timed out waiting for:"
    echo "  ${TOKEN_FILE}"
    echo "  ${PIN_FILE}"
    exit 1
  fi
  sleep 1
done

exec quantus-miner "$@"
