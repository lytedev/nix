# Agents

Instructions for AI coding agents working in this repository.

## Issue Tracking

Issues are tracked as markdown files in `issues/open/` and `issues/closed/`.

- Before starting work, check `issues/open/` for relevant context
- When creating a new issue, add a `.md` file to `issues/open/` with a `# Title` heading
- When resolving an issue, move its file from `open/` to `closed/`
- Use `**Labels**:` and `**Related**:` metadata lines where helpful

## Repository Structure

- `lib/modules/nixos/` — active NixOS module configuration
- `lib/modules/home/` — **dead code**, do not edit
- `packages/hosts/` — per-host NixOS configurations
- `dotfiles/` — config files symlinked into `~/.config/`
- `secrets/` — SOPS-encrypted secrets
- `lib/deploy/` — deploy-rs configuration
- `lib/doc/` — long-form documentation

## Version Control

This repo uses **jujutsu (jj)**, not git directly. Use `jj` commands for all
VCS operations. See the project CLAUDE.md for the jj quick reference.

## Nix

- Format with `nix fmt`
- Use `nix develop -c deploy` for deployments (not comma)
- Let CI handle big builds; don't build host configs locally unless necessary
