#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

VM_NAME="${1:-}"

echo "[PROC] muthr-services VM provisioning — SearXNG (containerd) + mcp-searxng"

if [[ -z "${VM_NAME}" ]]; then
    echo "[ERR] Target VM name required. Usage: $0 <vm-name>"
    exit 1
fi

if [[ ! "${VM_NAME}" =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "[ERR] Invalid VM name: ${VM_NAME}"
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
    limactl shell --workdir /tmp "$VM_NAME" -- bash -s < <(cat << 'EOF'
set -euo pipefail
umask 077
export DEBIAN_FRONTEND=noninteractive

SEARXNG_COMMIT="952896d29e1fdea8d2be89bf656c97036979f059"
SEARXNG_COMPOSE_URL="https://raw.githubusercontent.com/searxng/searxng/${SEARXNG_COMMIT}/container/docker-compose.yml"
SEARXNG_COMPOSE_SHA256="f476d3f9c5be24216ba1c762bffdb5985b64187559d869e15da3518dfd8b5a15"
MCP_SEARXNG_VERSION="1.7.2"

MCP_DIR="$HOME/.local"
SearxngDir="$HOME/searxng"
LOCK_FILE="$HOME/.muthr_provision.lock"
ENV_FINGERPRINT="muthr-services|${SEARXNG_COMMIT}|${SEARXNG_COMPOSE_SHA256}|${MCP_SEARXNG_VERSION}"

if [[ -f "$LOCK_FILE" ]] && [[ "$(cat "$LOCK_FILE" 2>/dev/null || true)" == "$ENV_FINGERPRINT" ]]; then
  echo "[INFO] environment already up to date with this target configuration profile."
  exit 0
fi

cleanup() {
  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    rm -f "$LOCK_FILE"
  fi
}
trap cleanup EXIT

if [ ! -f "${SearxngDir}/docker-compose.yml" ]; then
  echo "[PROC] Setting up SearXNG container..."
  mkdir -p "${SearxngDir}"

  curl -fsSL \
    -o "${SearxngDir}/docker-compose.yml" \
    "${SEARXNG_COMPOSE_URL}"
  echo "${SEARXNG_COMPOSE_SHA256}  ${SearxngDir}/docker-compose.yml" | sha256sum -c -

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
  npm install -g --prefix "${MCP_DIR}" --yes "mcp-searxng@${MCP_SEARXNG_VERSION}"
fi

if [ ! -f "$HOME/mcp-stdio.sh" ]; then
  echo "[PROC] Creating mcp-stdio.sh for SSH stdio bridge..."
  printf '%s\n' '#!/bin/bash' 'set -euo pipefail' "exec bash -l -c 'SEARXNG_URL=http://localhost:8080 node ${MCP_DIR}/lib/node_modules/mcp-searxng/dist/cli.js --stdio'" > "$HOME/mcp-stdio.sh"
  chmod +x "$HOME/mcp-stdio.sh"
fi

if ! grep -qF 'mcp-searxng PATH' "$HOME/.zshenv" 2>/dev/null; then
  printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.zshenv"
fi

printf '%s\n' "$ENV_FINGERPRINT" > "$LOCK_FILE"
chmod 600 "$LOCK_FILE"

echo "[ OK ] muthr-services VM provisioning complete"
EOF
)
}

_vm_run
