#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

# shellcheck source=sandbox.d/container/provision.d/lib/provision-lib.sh
source "$(dirname "$0")/lib/provision-lib.sh"

PROFILE_REV="2026-07-02.3"

OPENAI_URL="${MUTHR_INFERENCE_URL:?MUTHR_INFERENCE_URL is required}"
MODEL_NAME="${MUTHR_MODEL_NAME:?MUTHR_MODEL_NAME is required}"
ENGINE="${MUTHR_ENGINE_RUNTIME:?MUTHR_ENGINE_RUNTIME is required}"

echo "[PROC] Hermes-Agent environment provisioning..."

_lib_init_provision_state "hermes-agent" "$PROFILE_REV" "$OPENAI_URL" "$MODEL_NAME" "$ENGINE"

export DEBIAN_FRONTEND=noninteractive

if ! command -v uv &>/dev/null; then
    echo "[PROC] Installing uv..."
    UV_INSTALL_SCRIPT="$(mktemp)"
    curl -fsSL "https://astral.sh/uv/install.sh" -o "$UV_INSTALL_SCRIPT"
    sh "$UV_INSTALL_SCRIPT"
    rm -f "$UV_INSTALL_SCRIPT"
fi

export PATH="$HOME/.local/bin:$PATH"

if [ ! -d "$HOME/.hermes-runtime" ]; then
    echo "[PROC] Cloning Hermes Agent runtime..."
    git clone --depth 1 https://github.com/NousResearch/hermes-agent.git "$HOME/.hermes-runtime"
fi

cd "$HOME/.hermes-runtime"
if [ ! -d ".venv" ]; then
    echo "[PROC] Creating Hermes virtual environment..."
    uv venv --python 3.11
fi

source .venv/bin/activate
if ! uv pip show hermes-agent >/dev/null 2>&1; then
    echo "[PROC] Installing Hermes Agent package..."
    uv pip install -e .
fi

mkdir -p "$HOME/.local/bin"
for bin_name in hermes hermes-agent hermes-acp; do
    if [ -x "$HOME/.hermes-runtime/.venv/bin/$bin_name" ]; then
        ln -sf "$HOME/.hermes-runtime/.venv/bin/$bin_name" "$HOME/.local/bin/$bin_name"
    fi
done

PATH_SNIPPET='export PATH="$HOME/.local/bin:$HOME/.hermes-runtime/.venv/bin:$PATH"'
if ! grep -q 'hermes-runtime/.venv/bin' "$HOME/.bashrc" 2>/dev/null; then
    printf '\n# muthr hermes-agent\n%s\n' "$PATH_SNIPPET" >> "$HOME/.bashrc"
fi
if ! grep -q 'hermes-runtime/.venv/bin' "$HOME/.profile" 2>/dev/null; then
    printf '\n# muthr hermes-agent\n%s\n' "$PATH_SNIPPET" >> "$HOME/.profile"
fi

echo "[PROC] Writing Hermes configuration..."
mkdir -p "$HOME/.hermes"
cat > "$HOME/.hermes/config.json" << EOF
{
  "default_provider": "muthr-backend",
  "providers": {
    "muthr-backend": {
      "api_type": "openai",
      "base_url": "${OPENAI_URL}",
      "api_key": "sandbox-isolated-token",
      "default_model": "${MODEL_NAME}"
    }
  },
  "agent": {
    "system_prompt_patch": "You are executing code actions inside a locked zero-trust apple container sandbox boundary. Complete tasks cleanly."
  }
}
EOF

chmod 700 "$HOME/.hermes"
chmod 600 "$HOME/.hermes/config.json"

_lib_finalize_provision_state
echo "[ OK ] Hermes-Agent environment provisioned."
