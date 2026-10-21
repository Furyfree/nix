default:
    @just --list

# Run local checks without installing or activating a system
check: check-lua check-hyprland lint typecheck test eval

# Parse all native Lua configuration without executing it
check-lua:
    find configs -type f -name '*.lua' -exec luac -p {} +

# Validate Hyprland settings without starting a desktop or using live state
check-hyprland:
    #!/usr/bin/env bash
    set -euo pipefail
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
    Hyprland --verify-config --config "$config"
    # Each host file loads as ~/.config/hypr/host.lua next to the shared files.
    for host in configs/hypr/hosts/*.lua; do
        copy="$temporary/hypr-${host##*/}"
        cp -r configs/hypr "$copy"
        cp "$host" "$copy/host.lua"
        Hyprland --verify-config --config "$copy/hyprland.lua"
    done

lint:
    uv run --locked ruff check scripts tests
    uv run --locked ruff format --check scripts tests
    find . -type f -name '*.nix' -not -path './.venv/*' -not -path './.direnv/*' -not -path './hosts/*/local/*' -exec nixfmt --check {} +
    statix check
    find . -type f -name '*.nix' -not -path './.venv/*' -not -path './.direnv/*' -not -path './hosts/*/local/*' -exec deadnix --fail {} +

typecheck:
    uv run --locked basedpyright

test:
    uv run --locked pytest

# Format Python and Nix source files
format:
    uv run --locked ruff format scripts tests
    find . -type f -name '*.nix' -not -path './.venv/*' -not -path './.direnv/*' -not -path './hosts/*/local/*' -exec nixfmt {} +

# Evaluate configurations without building or deploying a system
eval:
    nix --extra-experimental-features 'nix-command flakes' flake check --no-build --no-write-lock-file path:.

# Build the installer ISO through the ignored result symlink
build-iso:
    nix --extra-experimental-features 'nix-command flakes' build --no-write-lock-file --out-link result path:.#nixosConfigurations.installer.config.system.build.isoImage
    @find result/iso -maxdepth 1 -type f -name '*.iso' -print

# Flash the built ISO; Caligula asks which drive to erase and confirms it
burn:
    #!/usr/bin/env bash
    set -euo pipefail
    shopt -s nullglob
    images=(result/iso/*.iso)
    if (( ${#images[@]} != 1 )) || [[ ! -f "${images[0]}" ]]; then
        printf 'Expected one ISO under result/iso/. Run just build-iso first.\n' >&2
        exit 1
    fi
    image=$(realpath -- "${images[0]}")
    caligula=$(command -v caligula)
    exec "$caligula" burn --interactive always "$image"

# Delete the linked ISO build; keep other builds and saved generations
clean-iso:
    #!/usr/bin/env bash
    set -euo pipefail
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

# Preview the shared installer wizard without making changes
wizard:
    uv run --locked python scripts/install.py --dry-run
