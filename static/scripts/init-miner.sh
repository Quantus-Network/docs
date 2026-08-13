#!/bin/sh
# Wait for miner auth files when the node/miner pair requires them, then exec.
# Mounted into the quantus-miner container by docker-compose.yml.
#
# If MINER_AUTH_TOKEN_FILE is unset/empty, this is a pre-auth (legacy) pair:
# skip the wait and do not pass auth flags.

set -e

if [ -z "${MINER_AUTH_TOKEN_FILE:-}" ]; then
  echo "Miner protocol: legacy (no auth files)"
  exec quantus-miner "$@"
fi

TOKEN_FILE="${MINER_AUTH_TOKEN_FILE}"
PIN_FILE="${MINER_TLS_CERT_SHA256_FILE:-}"

if [ -z "$PIN_FILE" ]; then
  echo "MINER_TLS_CERT_SHA256_FILE is required when MINER_AUTH_TOKEN_FILE is set"
  exit 1
fi

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

exec quantus-miner "$@" \
  --auth-token-file "$TOKEN_FILE" \
  --tls-cert-sha256-file "$PIN_FILE"
