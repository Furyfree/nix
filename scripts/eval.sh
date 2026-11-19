#!/usr/bin/env bash
# Evaluate configurations without building or deploying a system, and each
# NixOS host with every other compositor it can pick.
set -euo pipefail
cd "${0%/*}/.."
nix --extra-experimental-features 'nix-command flakes' flake check --no-build --no-write-lock-file path:.
# Pure evaluation cannot import a file from outside the flake, so pass its text.
nix --extra-experimental-features 'nix-command flakes' eval --no-write-lock-file --raw \
    path:.#nixosConfigurations --apply "$(<scripts/other-desktops.nix)"
