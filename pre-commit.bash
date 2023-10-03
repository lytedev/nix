#!/usr/bin/env bash

set -eux

nix flake check
nix run nixpkgs#alejandra -- --check .