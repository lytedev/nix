#!/usr/bin/env bash
# vibe code, yo

d="$HOME/.cache/vibe"
mkdir -p "$d"
nix shell nixpkgs#python3 -c python -m venv "$d"
source "$d/bin/activate"

# TODO: only run this if needed?
pip install -U google-generativeai boto3

GEMINI_API_KEY="$(comma yq .clients[0].api_key "$HOME/.config/aichat/config.yaml")"
export GEMINI_API_KEY

if [[ ! $* =~ --watch-files ]]; then
  echo 'TIP: Add "--watch-files" to interact with changes in your EDITOR.'
fi

DEFAULT_MODEL="gemini/gemini-2.5-pro-preview-03-25"

if [[ $PWD =~ bill ]]; then
  echo "In a \$JOB project. You may want to ensure AWS_PROFILE is set properly!"
  DEFAULT_MODEL="bedrock/us.anthropic.claude-sonnet-4-20250514-v1:0"
fi

if [[ $PWD =~ anglepoint ]]; then
  ANTHROPIC_API_KEY="$(comma yq .clients[1].api_key "$HOME/.config/aichat/config.yaml")"
  export ANTHROPIC_API_KEY
  DEFAULT_MODEL="sonnet"
fi

MODEL="${MODEL:-$DEFAULT_MODEL}"
echo "Using MODEL=${MODEL}"

# avoid using the nixpkgs registry entry, we want the latest hotness from unstable
AIDER_DARK_MODE=true nix shell "github:nixos/nixpkgs?rev=d31a91c9b3bee464d054633d5f8b84e17a637862#aider-chat-full" -c aider --model "$MODEL" "$@"
