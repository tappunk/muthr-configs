#!/usr/bin/env bash
set -Eeuo pipefail

VM_NAME="${1:-}"

echo "[PROC] Commencing isolation workspace provision for target VM: ${VM_NAME}..."

if [[ -z "${VM_NAME}" ]]; then
    echo "[ERR] Target execution container parameter undefined."
    exit 1
fi

if ! limactl ls -q | grep -q "^${VM_NAME}$"; then
    echo "[ERR] Destination virtual environment '${VM_NAME}' not registered in context."
    exit 1
fi

if limactl shell --workdir /tmp "${VM_NAME}" -- bash -c 'test -f "$HOME/.muthr_provision.lock"' 2>/dev/null; then
    echo "[WARN] OpenCode stack tracking indicates environment is already prepared. Skipping."
    exit 0
fi

limactl shell --workdir /tmp "${VM_NAME}" -- bash -c "
    if ! command -v npm &>/dev/null; then 
        export DEBIAN_FRONTEND=noninteractive; 
        sudo apt-get update -qq && sudo apt-get install -y -qq nodejs npm; 
    fi
"

echo "[PROC] Syncing global secure Node Model Context Protocol servers..."
limactl shell --workdir /tmp "${VM_NAME}" -- bash -c "
    sudo npm install -g --loglevel=silent \
        @ai-sdk/openai-compatible \
        @modelcontextprotocol/server-memory \
        @modelcontextprotocol/server-filesystem
"

echo "[PROC] Deploying system-wide instance of Astral UV package orchestrator..."
limactl shell --workdir /tmp "${VM_NAME}" -- bash -c "
    curl -LsSf https://astral.sh/uv/install.sh | sudo env UV_INSTALL_DIR='/usr/local/bin' sh
"

echo "[PROC] Installing OpenCode CLI from GitHub releases..."
limactl shell --workdir /tmp "${VM_NAME}" -- bash -c "
    curl -fsSL -o /tmp/opencode.tar.gz 'https://github.com/anomalyco/opencode/releases/latest/download/opencode-linux-arm64.tar.gz'
    sudo -n tar -xzf /tmp/opencode.tar.gz -C /usr/local/bin/ opencode
    rm /tmp/opencode.tar.gz
"

limactl shell --workdir /tmp "${VM_NAME}" -- bash -c 'touch "$HOME/.muthr_provision.lock"'

echo "[ OK ] Agent execution workspace environment online for ${VM_NAME}!"
