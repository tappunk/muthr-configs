#!/usr/bin/env bash
set -Eeuo pipefail

echo "[PROC] Commencing isolation workspace provision for target VM..."

if test -f "$HOME/.muthr_provision.lock" 2>/dev/null; then
    echo "[WARN] OpenCode stack tracking indicates environment is already prepared. Skipping."
    exit 0
fi

if ! command -v npm &>/dev/null; then
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get update -qq && sudo apt-get install -y -qq nodejs npm
fi

echo "[PROC] Syncing global secure Node Model Context Protocol servers..."
sudo npm install -g --loglevel=silent --yes \
    @ai-sdk/openai-compatible \
    @modelcontextprotocol/server-memory \
    @modelcontextprotocol/server-filesystem

echo "[PROC] Deploying system-wide instance of Astral UV package orchestrator..."
curl -LsSf https://astral.sh/uv/install.sh | sudo env UV_INSTALL_DIR='/usr/local/bin' sh

echo "[PROC] Installing OpenCode CLI from GitHub releases..."
curl -fsSL -o /tmp/opencode.tar.gz 'https://github.com/anomalyco/opencode/releases/latest/download/opencode-linux-arm64.tar.gz'
sudo -n tar -xzf /tmp/opencode.tar.gz -C /usr/local/bin/ opencode
rm /tmp/opencode.tar.gz

touch "$HOME/.muthr_provision.lock"

echo "[ OK ] Agent execution workspace environment online!"
