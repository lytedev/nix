#!/usr/bin/env bash
# vibe code, yo

MCP_DEBUG=${MCP_DEBUG:-0}

setup() {
d="$HOME/.cache/mcp-manager"

export UV_PYTHON_PREFERENCE=only-system
if [[ ! -d "$d" ]]; then
  nix shell nixpkgs#uv nixpkgs#python3 -c uv venv -p "$(which python3)" "$d"
fi

export UV_PYTHON_PREFERENCE=only-system
source "$d/bin/activate"

export UV_PYTHON_PREFERENCE=only-system
git clone "https://github.com/lutzleonhardt/mcpm-aider.git" "$d/mcpm-aider"
cd "$d/mcpm-aider" || exit 1
git submodule init
git submodule update

export UV_PYTHON_PREFERENCE=only-system
nix shell nixpkgs#uv nixpkgs#python3 nixpkgs#pnpm nixpkgs#nodejs -c pnpm i
}

if [[ $MCP_DEBUG == 0 ]]; then
  setup &>/dev/null
else
  setup
fi

nix shell nixpkgs#uv nixpkgs#python3 nixpkgs#pnpm nixpkgs#nodejs -c pnpm start "$@"
