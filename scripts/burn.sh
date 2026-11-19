#!/usr/bin/env bash
# Flash the built ISO; Caligula asks which drive to erase and confirms it.
set -euo pipefail
shopt -s nullglob
cd "${0%/*}/.."
images=(result/iso/*.iso)
if (( ${#images[@]} != 1 )) || [[ ! -f "${images[0]}" ]]; then
    printf 'Expected one ISO under result/iso/. Run just build-iso first.\n' >&2
    exit 1
fi
image=$(realpath -- "${images[0]}")
caligula=$(command -v caligula)
exec "$caligula" burn --interactive always "$image"
