#!/bin/bash
# Runs from the Automations/ folder of the application repo.
# Sets VITE_API_PATH in frontend/.env.docker to this server's public IP (or an IP passed as $1).
# Fails loudly if no valid IP can be determined.
set -euo pipefail

ipv4_address="${1:-}"
if [[ -z "$ipv4_address" ]]; then
    ipv4_address=$(curl -s --max-time 10 http://checkip.amazonaws.com | tr -d '[:space:]' || true)
fi

if [[ ! "$ipv4_address" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "ERROR: Could not determine a valid public IP (got: '${ipv4_address}')" >&2
    exit 1
fi

file_to_find="../frontend/.env.docker"
if [[ ! -f "$file_to_find" ]]; then
    echo "ERROR: $file_to_find not found." >&2
    exit 1
fi

sed -i -e "s|VITE_API_PATH.*|VITE_API_PATH=\"http://${ipv4_address}:31100\"|g" "$file_to_find"
echo "VITE_API_PATH set to http://${ipv4_address}:31100"
