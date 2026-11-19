default:
    @just --list

# Run local checks without installing or activating a system
check: check-lua check-hyprland check-niri check-powershell lint typecheck test eval eval-local

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

# Validate Niri settings without starting a desktop
check-niri:
    #!/usr/bin/env bash
    set -euo pipefail
    shopt -s nullglob
    temporary=$(mktemp -d)
    trap 'rm -rf -- "$temporary"' EXIT
    niri validate --config configs/niri/config.kdl
    # Each host file loads as ~/.config/niri/host.kdl next to the shared file.
    for host in configs/niri/hosts/*.kdl; do
        copy="$temporary/niri-${host##*/}"
        cp -r configs/niri "$copy"
        cp "$host" "$copy/host.kdl"
        niri validate --config "$copy/config.kdl"
    done

# Parse the Windows scripts without running them, and load each Windows profile
# and the layers, registry files and configs it names
[extension: '.ps1']
check-powershell:
    #!/usr/bin/env pwsh
    $ErrorActionPreference = 'Stop'
    foreach ($script in Get-ChildItem windows, configs -Recurse -Filter *.ps1) {
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref]$null, [ref]$errors)
        if ($errors) { throw "$($script): $($errors[0])" }
    }
    foreach ($file in Get-ChildItem windows/profiles -Filter *.psd1) {
        $layer = Import-PowerShellDataFile $file.FullName
        foreach ($name in $layer.Include) {
            if (-not (Test-Path "windows/profiles/$name.psd1")) { throw "$($file.Name): no layer $name" }
        }
        foreach ($name in $layer.Registry) {
            if (-not (Test-Path "windows/registry/$name")) { throw "$($file.Name): no registry file $name" }
        }
        $configs = @($layer.Links.Values) + @($layer.Merges.Values | ForEach-Object { $_ }) +
            @($layer.Extensions.Values | ForEach-Object { $_ } | Where-Object { $_ -like '*/*' }) + @($layer.Taskbar)
        foreach ($name in $configs | Where-Object { $_ }) {
            if (-not (Test-Path "configs/$name")) { throw "$($file.Name): no configs/$name" }
        }
    }

lint:
    cd nixos/installer && uv run --locked ruff check .
    cd nixos/installer && uv run --locked ruff format --check .
    find . -type f -name '*.nix' -not -path './.venv/*' -not -path './.direnv/*' -not -path '*/local/*' -not -path './nixos/pins/_sources/*' -exec nixfmt --check {} +
    statix check
    find . -type f -name '*.nix' -not -path './.venv/*' -not -path './.direnv/*' -not -path '*/local/*' -not -path './nixos/pins/_sources/*' -exec deadnix --fail {} +

typecheck:
    cd nixos/installer && uv run --locked basedpyright

test:
    cd nixos/installer && uv run --locked pytest

# Format Python and Nix source files
format:
    cd nixos/installer && uv run --locked ruff format .
    find . -type f -name '*.nix' -not -path './.venv/*' -not -path './.direnv/*' -not -path '*/local/*' -not -path './nixos/pins/_sources/*' -exec nixfmt {} +

# Evaluate configurations without building or deploying a system, and each
# NixOS host with every other compositor it can pick
eval:
    #!/usr/bin/env bash
    set -euo pipefail
    nix --extra-experimental-features 'nix-command flakes' flake check --no-build --no-write-lock-file path:.
    nix --extra-experimental-features 'nix-command flakes' eval --no-write-lock-file --raw \
        path:.#nixosConfigurations --apply '
        hosts:
        let
          other = name: desktop:
            let
              host = hosts.${name}.extendModules {
                modules = [ ({ lib, ... }: { workstation.desktop = lib.mkForce desktop; }) ];
              };
            in
            "${name} (${desktop}): ${host.config.system.build.toplevel.drvPath}\n";
          evaluate = name:
            let
              inherit (hosts.${name}) config options;
            in
            map (other name) (
              builtins.filter (desktop: desktop != config.workstation.desktop)
                options.workstation.desktop.type.functor.payload.values
            );
        in
        builtins.concatStringsSep "" (
          builtins.concatMap evaluate (
            builtins.filter (name: hosts.${name}.options ? workstation) (builtins.attrNames hosts)
          )
        )'

# Evaluate each Mac profile, Ubuntu and NixOS in WSL from a temporary checkout
# with a placeholder user; none has an output here without its ignored
# local/user.nix
eval-local:
    #!/usr/bin/env bash
    set -euo pipefail
    temporary=$(mktemp -d)
    trap 'rm -rf -- "$temporary"' EXIT
    # Tracked and new files; ignored machine data stays out.
    git ls-files -z --cached --others --exclude-standard |
        while IFS= read -r -d '' file; do
            # Files deleted but not yet committed are still listed.
            if [[ -e $file ]]; then
                cp -P --parents -- "$file" "$temporary"
            fi
        done
    mkdir -p "$temporary/darwin/local"
    for profile in personal work; do
        printf '{ imports = [ ../%s.nix ]; system.primaryUser = "alice"; }\n' "$profile" \
            >"$temporary/darwin/local/user.nix"
        printf 'macos (%s): ' "$profile"
        nix --extra-experimental-features 'nix-command flakes' eval --no-write-lock-file --raw \
            "path:$temporary#darwinConfigurations.macos.system.drvPath"
        echo
    done
    mkdir -p "$temporary/ubuntu/local"
    printf '{ home.username = "alice"; home.homeDirectory = "/home/alice"; }\n' \
        >"$temporary/ubuntu/local/user.nix"
    printf 'ubuntu: '
    nix --extra-experimental-features 'nix-command flakes' eval --no-write-lock-file --raw \
        "path:$temporary#homeConfigurations.ubuntu.activationPackage.drvPath"
    echo
    mkdir -p "$temporary/nixos/hosts/wsl/local"
    printf '{ wsl.defaultUser = "alice"; }\n' >"$temporary/nixos/hosts/wsl/local/user.nix"
    printf 'wsl: '
    nix --extra-experimental-features 'nix-command flakes' eval --no-write-lock-file --raw \
        "path:$temporary#nixosConfigurations.wsl.config.system.build.toplevel.drvPath"
    echo

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
    cd nixos/installer && uv run --locked python install.py --dry-run
