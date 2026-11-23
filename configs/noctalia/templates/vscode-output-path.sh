#!/usr/bin/env bash
set -euo pipefail

# Noctalia consumes stdout as paths. Never guess a version or create an extension.
command -v code >/dev/null 2>&1 || exit 0

extension_dir=$(code --locate-extension noctalia.noctaliatheme)
[[ -n "$extension_dir" ]] || exit 0
case "$extension_dir" in
    /*) ;;
    *) printf '%s\n' 'VS Code returned a relative extension path.' >&2; exit 1 ;;
esac
if [[ "$extension_dir" == *$'\n'* || ! -f "$extension_dir/package.json" ||
      ! -f "$extension_dir/themes/NoctaliaTheme-color-theme.json" ]]; then
    printf '%s\n' 'VS Code returned an incomplete or ambiguous Noctalia extension.' >&2
    exit 1
fi
printf '%s/themes/NoctaliaTheme-color-theme.json\n' "$extension_dir"
