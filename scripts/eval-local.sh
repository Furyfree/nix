#!/usr/bin/env bash
# Evaluate each Mac profile, Ubuntu and NixOS in WSL from a temporary checkout
# with a placeholder user; none has an output here without its ignored
# local/user.nix.
set -euo pipefail
cd "${0%/*}/.."
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
    drv=$(nix --extra-experimental-features 'nix-command flakes' eval --no-write-lock-file --raw \
        "path:$temporary#darwinConfigurations.macos.system.drvPath")
    printf 'macos (%s): %s\n' "$profile" "$drv"
done
mkdir -p "$temporary/ubuntu/local"
printf '{ home.username = "alice"; home.homeDirectory = "/home/alice"; }\n' \
    >"$temporary/ubuntu/local/user.nix"
drv=$(nix --extra-experimental-features 'nix-command flakes' eval --no-write-lock-file --raw \
    "path:$temporary#homeConfigurations.ubuntu.activationPackage.drvPath")
printf 'ubuntu: %s\n' "$drv"
mkdir -p "$temporary/nixos/hosts/wsl/local"
printf '{ wsl.defaultUser = "alice"; }\n' >"$temporary/nixos/hosts/wsl/local/user.nix"
drv=$(nix --extra-experimental-features 'nix-command flakes' eval --no-write-lock-file --raw \
    "path:$temporary#nixosConfigurations.wsl.config.system.build.toplevel.drvPath")
printf 'wsl: %s\n' "$drv"
