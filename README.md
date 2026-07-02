![muthr-specs](https://raw.githubusercontent.com/tappunk/.github/refs/heads/main/assets/muthr-specs.webp)

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![X Follow](https://img.shields.io/twitter/follow/tappunk?style=social)](https://x.com/tappunk)

# muthr-specs
> \[!NOTE]
> Source-of-truth specs deployed by `muthr init` into `~/.config/muthr/`.

Canonical documentation: **https://tappunk.com/muthr/**

Configuration files for [muthr](https://github.com/tappunk/muthr).

[Structure](#structure) • [Profiles](#profiles) • [Environment Variables](#environment-variables) • [Adding a New Profile](#adding-a-new-profile)

## Installation

```bash
muthr init
```

Use a custom specs repo:

```bash
muthr init --git-url https://github.com/custom/muthr-specs.git
```

See [muthr](https://github.com/tappunk/muthr) for architecture and usage.

## Structure

```
muthr-specs/
├── sandbox.d/container/
│   ├── manifests/               # Container manifests
│   └── provision.d/             # Provision scripts + shared lib/
├── provider.d/                  # Engine model presets (INI)
├── clients/                     # Reference config templates
└── LICENSE
```

See [muthr](https://github.com/tappunk/muthr) for architecture details.

## Profiles

Profile assets live in `sandbox.d/container/`. See [muthr](https://github.com/tappunk/muthr) for documentation.

### base

Minimal Debian 13 container.

### opencode

Installs opencode CLI and MCP servers.

### hermes-agent

Installs the Hermes-Agent runtime in an isolated Python/uv environment.

### muthr-services

Persistent services container for SearXNG and MCP bridge.

### provider presets

Preset INI files in `provider.d/{mlxcel,llama}/` are consumed by `muthr` runtime selection and `engine presets` output.

## Environment Variables

See [muthr](https://github.com/tappunk/muthr) for environment variable documentation.

Runtime contract highlights:

- `MUTHR_INFERENCE_URL` primary inference endpoint inside the sandbox
- `MUTHR_OPENAI_URL` compatibility alias of inference endpoint
- `MUTHR_MCP_BRIDGE_URL` MCP bridge endpoint exposed by `muthr-services`
- `MUTHR_SEARXNG_URL` SearXNG endpoint exposed by `muthr-services`

For restricted profiles, use `muthr image build --profile <name>` to pre-bake golden images and avoid WAN bootstrap at sandbox start.

Workspace safety:

- Set `workspace_root` / `MUTHR_WORKSPACE_ROOT` to a dedicated subdirectory (for example `~/src`), never `$HOME`.
- `muthr` rejects `$HOME` as workspace root to prevent mounting your entire home directory into sandbox containers.

## Script conventions

- Use `set -Eeuo pipefail`
- Set `DEBIAN_FRONTEND=noninteractive`
- Keep shared helpers in `sandbox.d/container/provision.d/lib/`

## Adding a New Profile

1. Create `sandbox.d/container/provision.d/<profile>.sh`
2. Optionally add `sandbox.d/container/manifests/<profile>.yaml`
3. Optionally add a reference template under `clients/`

See [muthr](https://github.com/tappunk/muthr) for usage and architecture.

## Acknowledgements

- [llama.cpp](https://github.com/ggml-org/llama.cpp)
- [mlxcel](https://github.com/lablup/mlxcel)
- [Apple container](https://github.com/apple/container)
