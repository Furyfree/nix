default:
    @just --list

# Run local checks without installing or activating a system
check: lint typecheck test eval

lint:
    uv run --locked ruff check scripts tests
    uv run --locked ruff format --check scripts tests
    find . -type f -name '*.nix' -not -path './.venv/*' -not -path './.direnv/*' -exec nixfmt --check {} +
    statix check
    deadnix --fail .

typecheck:
    uv run --locked basedpyright

test:
    uv run --locked pytest

# Format Python and Nix source files
format:
    uv run --locked ruff format scripts tests
    find . -type f -name '*.nix' -not -path './.venv/*' -not -path './.direnv/*' -exec nixfmt {} +

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

# Globally delete unused Nix store paths without deleting saved generations
gc:
    nix-collect-garbage

# Preview the shared installer wizard without making changes
wizard:
    uv run --locked python scripts/install.py --dry-run
