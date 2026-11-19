nix_files := "find . -type f -name '*.nix' -not -path './.venv/*' -not -path './.direnv/*' -not -path '*/local/*' -not -path './nixos/pins/_sources/*'"

default:
    @just --list

# Run local checks without installing or activating a system
check:
    scripts/check.sh

# Parse all native Lua configuration without executing it
check-lua:
    find configs -type f -name '*.lua' -exec luac -p {} +

# Validate Hyprland settings without starting a desktop or using live state
check-hyprland:
    scripts/check-hyprland.sh

# Validate Niri settings without starting a desktop
check-niri:
    scripts/check-niri.sh

# Parse the Windows scripts and check the files each Windows profile names
check-powershell:
    scripts/check-powershell.ps1

lint:
    cd nixos/installer && uv run --locked ruff check .
    cd nixos/installer && uv run --locked ruff format --check .
    {{ nix_files }} -exec nixfmt --check {} +
    statix check
    {{ nix_files }} -exec deadnix --fail {} +

typecheck:
    cd nixos/installer && uv run --locked basedpyright

test:
    cd nixos/installer && uv run --locked pytest

# Format Python and Nix source files
format:
    cd nixos/installer && uv run --locked ruff format .
    {{ nix_files }} -exec nixfmt {} +

# Evaluate every output, and each NixOS host with its other compositors
eval:
    scripts/eval.sh

# Evaluate the Macs, Ubuntu and NixOS in WSL with a placeholder user
eval-local:
    scripts/eval-local.sh

# Build the installer ISO through the ignored result symlink
build-iso:
    nix --extra-experimental-features 'nix-command flakes' build --no-write-lock-file --out-link result path:.#nixosConfigurations.installer.config.system.build.isoImage
    @find result/iso -maxdepth 1 -type f -name '*.iso' -print

# Flash the built ISO; Caligula asks which drive to erase and confirms it
burn:
    scripts/burn.sh

# Delete the linked ISO build; keep other builds and saved generations
clean-iso:
    scripts/clean-iso.sh

# Preview the shared installer wizard without making changes
wizard:
    cd nixos/installer && uv run --locked python install.py --dry-run
