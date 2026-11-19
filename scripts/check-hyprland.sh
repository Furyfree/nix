#!/usr/bin/env bash
# Validate Hyprland settings without starting a desktop or using live state.
set -euo pipefail
cd "${0%/*}/.."
config=$(realpath configs/hypr/hyprland.lua)
temporary=$(mktemp -d)
trap 'rm -rf -- "$temporary"' EXIT
export HOME="$temporary"
export XDG_CONFIG_HOME="$temporary/config" XDG_STATE_HOME="$temporary/state"
export XDG_CACHE_HOME="$temporary/cache" XDG_DATA_HOME="$temporary/data"
export XDG_RUNTIME_DIR="$temporary/runtime"
mkdir -m 700 "$XDG_RUNTIME_DIR"
unset HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY DISPLAY DBUS_SESSION_BUS_ADDRESS
unset LUA_PATH LUA_CPATH

# Hyprland logs at length even when the config is fine; show it on failure.
verify() {
    local output
    if ! output=$(Hyprland --verify-config --config "$2" 2>&1); then
        printf '%s\n%s: failed\n' "$output" "$1" >&2
        return 1
    fi
    printf '%s: ok\n' "$1"
}

verify hyprland "$config"
# Each host file loads as ~/.config/hypr/host.lua next to the shared files.
for host in configs/hypr/hosts/*.lua; do
    name=${host##*/}
    copy="$temporary/hypr-$name"
    cp -r configs/hypr "$copy"
    cp "$host" "$copy/host.lua"
    verify "hyprland (${name%.lua})" "$copy/hyprland.lua"
done
