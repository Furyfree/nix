#!/usr/bin/env bash
# Delete the linked ISO build; keep other builds and saved generations.
set -euo pipefail
cd "${0%/*}/.."
if [[ ! -L result ]]; then
    if [[ -e result ]]; then
        printf 'Refusing cleanup: result is not a symlink.\n' >&2
        exit 1
    fi
    printf 'No linked ISO to clean.\n'
    exit 0
fi
if [[ ! -e result ]]; then
    unlink -- result
    printf 'Removed broken result link.\n'
    exit 0
fi
link=$(readlink -- result)
output=$(readlink -f -- result)
if [[ "$output" != /nix/store/* || ! -d "$output/iso" ]] ||
   [[ -z $(find "$output/iso" -maxdepth 1 -type f -name '*.iso' -print -quit) ]]; then
    printf 'Refusing cleanup: result is not a Nix ISO output.\n' >&2
    exit 1
fi
unlink -- result
if ! nix-store --delete "$output"; then
    ln -sT -- "$link" result
    printf 'Cleanup failed; restored result link.\n' >&2
    exit 1
fi
