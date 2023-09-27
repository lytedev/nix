#!/usr/bin/env bash

set -eux

nix flake check
nixpkgs-fmt --check .
