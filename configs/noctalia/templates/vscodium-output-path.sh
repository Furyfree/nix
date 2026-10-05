#!/usr/bin/env bash
set -euo pipefail

# Noctalia consumes stdout as paths. Never guess a version or create an extension.
if command -v codium >/dev/null 2>&1; then
    editor=codium
elif command -v vscodium >/dev/null 2>&1; then
    editor=vscodium
else
    exit 0
fi

extension_dir=$("$editor" --locate-extension noctalia.noctaliatheme)
[[ -n "$extension_dir" ]] || exit 0
case "$extension_dir" in
    /*) ;;
    *) printf '%s\n' 'VSCodium returned a relative extension path.' >&2; exit 1 ;;
esac
if [[ "$extension_dir" == *$'\n'* || ! -f "$extension_dir/package.json" ||
      ! -f "$extension_dir/themes/NoctaliaTheme-color-theme.json" ]]; then
    printf '%s\n' 'VSCodium returned an incomplete or ambiguous Noctalia extension.' >&2
    exit 1
fi
printf '%s/themes/NoctaliaTheme-color-theme.json\n' "$extension_dir"
