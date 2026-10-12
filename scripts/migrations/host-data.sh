#!/usr/bin/env bash
# One-time migration of the old nixos-test machine files. No activation.
set -euo pipefail

fail() { printf '%s\n' "$*" >&2; exit 1; }
trap 'printf "Migration stopped. Inspect originals, local data and backups before retrying.\n" >&2' ERR

preview=false
case "${1:-}" in
    --dry-run) preview=true ;;
    '') ;;
    *) fail "Usage: bash scripts/migrations/host-data.sh [--dry-run]" ;;
esac
(( $# <= 1 )) || fail "Unexpected arguments."

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
host="$repo/hosts/nixos-test"
local="$host/local"
hardware=hosts/nixos-test/hardware-configuration.nix
installation=hosts/nixos-test/installation.nix
for directory in "$repo" "$repo/.git" "$repo/hosts" "$host"; do
    [[ -d "$directory" && ! -L "$directory" ]] || fail "Requires a standalone checkout without symlinks."
done
[[ $(git -C "$repo" rev-parse --show-toplevel) == "$repo" ]] || fail "Wrong checkout root."
[[ ! -e "$local" && ! -L "$local" ]] || fail "Local data already exists; refusing overwrite."
for file in "$hardware" "$installation" flake.lock; do
    [[ -f "$repo/$file" && ! -L "$repo/$file" ]] || fail "Missing or unsafe file: $file"
done
status=$(git -C "$repo" status --porcelain)
while IFS= read -r entry; do
    case "$entry" in
        ''|" M $hardware"|"?? $installation") ;;
        *) fail "Unrelated checkout changes; migration refused." ;;
    esac
done <<< "$status"
for name in hardware-configuration.nix installation.nix; do
    git -C "$repo" check-ignore -q -- "hosts/nixos-test/local/$name"
done
[[ -z $(git -C "$repo" ls-files -- hosts/nixos-test/local) ]] || fail "Local data must not be tracked."
for reference in 'import ../../components/swap.nix' 'import ./home.nix'; do
    count=$(grep -Fo -- "$reference" "$repo/$installation" | wc -l) || fail "Unrecognized installation imports."
    (( count == 1 )) || fail "Unrecognized installation imports."
done

backup_root="${XDG_STATE_HOME:-$HOME/.local/state}/nix/host-data-migrations"
[[ "$backup_root" == /* ]] || fail "Backup path must be absolute."
backup_root=$(realpath -m -s -- "$backup_root")
case "$backup_root" in
    "$repo"|"$repo"/*) fail "Backups must stay outside the checkout." ;;
esac
ancestor="$backup_root"
while [[ "$ancestor" != / ]]; do
    [[ ! -L "$ancestor" ]] || fail "Backup path contains a symlink."
    ancestor=$(dirname -- "$ancestor")
done

# Identical system output protects account, disk, swap and resume configuration.
flake="path:$repo#nixosConfigurations.nixos-test.config.system.build.toplevel"
system_output() {
    timeout --foreground 300 nix --extra-experimental-features 'nix-command flakes' \
        eval --raw --no-write-lock-file --no-update-lock-file "$flake.outPath"
}
before=$(system_output)
[[ "$before" == /nix/store/* ]] || fail "Invalid system output."
if "$preview"; then
    printf 'Would back up to %s and migrate into %s. No activation.\n' "$backup_root" "$local"
    exit 0
fi

umask 077
mkdir -p -- "$backup_root"
backup=$(mktemp -d -- "$backup_root/nixos-test-XXXXXXXX")
cp -- "$repo/$hardware" "$backup/hardware-configuration.nix"
cp -- "$repo/$installation" "$backup/installation.nix"
cp -- "$repo/flake.lock" "$backup/flake.lock"
sed \
    -e 's#import \.\./\.\./components/swap\.nix#import ../../../components/swap.nix#' \
    -e 's#import \./home\.nix#import ../home.nix#' \
    "$backup/installation.nix" > "$backup/installation.local.nix"
printf 'Originals backed up at %s\n' "$backup"
mkdir -- "$local"
cp -- "$backup/hardware-configuration.nix" "$local/hardware-configuration.nix"
cp -- "$backup/installation.local.nix" "$local/installation.nix"
[[ $(system_output) == "$before" ]] || fail "System output changed; originals and backups kept."
timeout --foreground 1800 nix --extra-experimental-features 'nix-command flakes' \
    build --no-link --no-write-lock-file --no-update-lock-file "$flake"
[[ $(system_output) == "$before" ]] || fail "System output changed during the build."
cmp -- "$repo/flake.lock" "$backup/flake.lock"
cmp -- "$repo/$hardware" "$backup/hardware-configuration.nix"
cmp -- "$repo/$installation" "$backup/installation.nix"
cmp -- "$local/hardware-configuration.nix" "$backup/hardware-configuration.nix"
cmp -- "$local/installation.nix" "$backup/installation.local.nix"
# Retire legacy files only after the unchanged configuration builds successfully.
git -C "$repo" restore --source=HEAD -- "$hardware"
rm -- "$repo/$installation"
[[ -z $(git -C "$repo" status --porcelain) ]] || fail "Build passed, but checkout is not clean; backups kept."
printf 'Machine data migrated; system output unchanged, build passed. Checkout clean. No activation.\n'
