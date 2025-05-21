#!/usr/bin/env bash
# vibe code, yo

d="$HOME/.cache/vibe"
mkdir -p "$d"
nix shell nixpkgs#python3 -c python -m venv "$d"
source "$d/bin/activate"
pip install -U google-generativeai boto3

GEMINI_API_KEY="$(comma yq .clients[0].api_key "$HOME/.config/aichat/config.yaml")"
export GEMINI_API_KEY

# recommend passing "--watch-files" for having aider work in any IDE, including terminal ones
# https://aider.chat/docs/usage/watch.html
echo "Additional aider args: $*"

# MODEL="${MODEL:-gemini/gemini-2.0-flash}"
# MODEL="bedrock/anthropic.claude-3-7-sonnet-20250219-v1:0"
MODEL="${MODEL:-"gemini/gemini-2.5-pro-preview-03-25"}"

# avoid using the nixpkgs registry entry, we want the latest hotness from unstable
AIDER_DARK_MODE=true nix shell "github:nixos/nixpkgs?rev=648a999c9cebef4b2ab474f4a85dd3679309bd28#aider-chat-full" -c aider --model "$MODEL" "$@"
