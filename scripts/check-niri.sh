#!/usr/bin/env bash
# Validate Niri settings without starting a desktop.
set -euo pipefail
shopt -s nullglob
cd "${0%/*}/.."
temporary=$(mktemp -d)
trap 'rm -rf -- "$temporary"' EXIT

# Niri logs every include it misses even when the config is fine; show it on
# failure.
verify() {
    local output
    if ! output=$(niri validate --config "$2" 2>&1); then
        printf '%s\n%s: failed\n' "$output" "$1" >&2
        return 1
    fi
    printf '%s: ok\n' "$1"
}

verify niri configs/niri/config.kdl
# Each host file loads as ~/.config/niri/host.kdl next to the shared file.
for host in configs/niri/hosts/*.kdl; do
    name=${host##*/}
    copy="$temporary/niri-$name"
    cp -r configs/niri "$copy"
    cp "$host" "$copy/host.kdl"
    verify "niri (${name%.kdl})" "$copy/config.kdl"
done
