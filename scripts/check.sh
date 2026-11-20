#!/usr/bin/env bash
# Run the local checks. The Nix evaluations run in the background and print
# once done; the rest runs in order and streams with its colours.
set -euo pipefail
cd "${0%/*}/.."
temporary=$(mktemp -d)
trap 'rm -rf -- "$temporary"' EXIT

background=(eval eval-local)
pids=()
for step in "${background[@]}"; do
    just "$step" >"$temporary/$step" 2>&1 &
    pids+=("$!")
done

failed=()
for step in check-shell check-lua check-hyprland check-niri check-powershell lint typecheck test; do
    just "$step" || failed+=("$step")
done
for i in "${!background[@]}"; do
    wait "${pids[i]}" || failed+=("${background[i]}")
    cat "$temporary/${background[i]}"
done

if ((${#failed[@]})); then
    printf 'Failed: %s\n' "${failed[*]}" >&2
    exit 1
fi
