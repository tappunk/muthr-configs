#!/usr/bin/env bash
set -Eeuo pipefail

VM_NAME="${1:-}"

echo "[PROC] MCP VM provisioning — SearXNG (containerd) + mcp-searxng"

if [[ -z "${VM_NAME}" ]]; then
    echo "[ERR] Target VM name required. Usage: $0 <vm-name>"
    exit 1
fi

# Self-detect: if we can reach the VM via Lima, we're on the host and need limactl shell
_vm_reachable() {
    limactl shell --workdir /tmp "$VM_NAME" -- bash -c 'echo reachable' >/dev/null 2>&1
}

if ! _vm_reachable; then
    echo "[ERR] VM '$VM_NAME' is not registered or not running."
    exit 1
fi

_vm_run() {
    limactl shell --workdir /tmp "$VM_NAME" -- bash -s << 'EOF'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

MCP_DIR="$HOME/.local"
SearxngDir="$HOME/searxng"

if [ ! -f "${SearxngDir}/docker-compose.yml" ]; then
  echo "[PROC] Setting up SearXNG container..."
  mkdir -p "${SearxngDir}"

  curl -fsSL \
    -o "${SearxngDir}/docker-compose.yml" \
    "https://raw.githubusercontent.com/searxng/searxng/master/container/docker-compose.yml"

  SECRET_KEY=$(openssl rand -hex 32)
  printf 'SEARXNG_SETTINGS_PATH=/etc/searxng/settings.yml\nSEARXNG_SECRET=%s\n' "${SECRET_KEY}" > "${SearxngDir}/.env"
  mkdir -p "${SearxngDir}/core-config"
  printf 'use_default_settings: true\nsearch:\n  formats:\n    - html\n    - json\n' > "${SearxngDir}/core-config/settings.yml"

  cd "${SearxngDir}" && nerdctl compose up -d
fi

echo "[PROC] Ensuring mcp-searxng is installed..."
if [ ! -f "${MCP_DIR}/lib/node_modules/mcp-searxng/dist/cli.js" ]; then
  echo "[PROC] Installing mcp-searxng..."
  mkdir -p "${MCP_DIR}/lib"
  npm install -g --prefix "${MCP_DIR}" --yes mcp-searxng
fi

if [ ! -f "$HOME/mcp-stdio.sh" ]; then
  echo "[PROC] Creating mcp-stdio.sh for SSH stdio bridge..."
  printf '%s\n' '#!/bin/bash' 'set -euo pipefail' "exec bash -l -c 'SEARXNG_URL=http://localhost:8080 node ${MCP_DIR}/lib/node_modules/mcp-searxng/dist/cli.js --stdio'" > "$HOME/mcp-stdio.sh"
  chmod +x "$HOME/mcp-stdio.sh"
fi

if ! grep -qF 'mcp-searxng PATH' "$HOME/.zshenv" 2>/dev/null; then
  printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.zshenv"
fi

echo "[ OK ] MCP VM provisioning complete"
EOF
}

_vm_run
