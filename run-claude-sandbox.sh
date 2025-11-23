#!/usr/bin/env bash
container_run_command=docker
if command -v podman &>/dev/null; then
  container_run_command=podman
fi
$container_run_command run -it --rm \
  --name claude-sandbox \
  --network none \
  --cpus="2" \
  --memory="4g" \
  --security-opt=no-new-privileges \
  --cap-drop=ALL \
  --tmpfs /tmp:rw,noexec,nosuid,size=2g \
  --tmpfs /run:rw,noexec,nosuid,size=200m \
  -v /nix/store:/nix/store:ro \
  -v "$HOME/.home/Documents/code/nix:/flake:ro" \
  -v "$(pwd):/workspace:ro" \
  -w /workspace \
  ghcr.io/determinatesystems/nix:latest \
  nix run '/flake#claude-cli' --impure
