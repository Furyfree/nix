#!/usr/bin/env bash
# Merge managed preferences into writable local files; never read secrets into Nix.
set -euo pipefail
umask 077

format=$1
defaults=$2
target=$3
operation=${4:-'.[0] * .[1]'}

fail() {
  printf 'Home Manager: %s; leaving %s untouched.\n' "$1" "$target" >&2
  exit 1
}

case "$format" in
  json|toml) ;;
  *) fail 'unsupported settings format' ;;
esac
[[ ! -L "$target" && ( ! -e "$target" || -f "$target" ) ]] || fail 'settings must be a regular file'
[[ -f "$defaults" ]] || fail 'managed preferences are missing'

work=$(mktemp -d)
staged=
trap 'rm -rf -- "$work"; if [[ -n "$staged" ]]; then rm -f -- "$staged"; fi' EXIT
cp -- "$defaults" "$work/defaults"
existed=false
if [[ -e "$target" ]]; then
  existed=true
  cp -- "$target" "$work/original"
elif [[ "$format" == json ]]; then
  printf '{}\n' > "$work/original"
else
  : > "$work/original"
fi

if [[ "$format" == json ]]; then
  # JSON5 also accepts JSONC comments and trailing commas used by the editors.
  json5 --as-json "$work/original" > "$work/local.json" 2>/dev/null || fail 'invalid local JSON settings'
  json5 --as-json "$work/defaults" > "$work/managed.json" 2>/dev/null || fail 'invalid managed JSON settings'
  jq -e 'type == "object"' "$work/local.json" > /dev/null || fail 'local settings must be an object'
  jq -e 'type == "object"' "$work/managed.json" > /dev/null || fail 'managed settings must be an object'
  jq -e -s "$operation" "$work/local.json" "$work/managed.json" > "$work/new" 2>/dev/null || fail 'JSON merge failed'
  jq -e 'type == "object"' "$work/new" > /dev/null || fail 'merged settings must be an object'
  if "$existed" && jq -e -s '.[0] == .[1]' "$work/local.json" "$work/new" > /dev/null; then
    exit 0
  fi
else
  # Merge TOML directly so dates and large integers keep their native types.
  yq eval-all -p toml -o toml '(select(fileIndex == 0) // {}) * select(fileIndex == 1)' \
    "$work/original" "$work/defaults" > "$work/new" 2>/dev/null || fail 'invalid TOML settings or failed merge'
  yq -e -p toml 'tag == "!!map"' "$work/new" > /dev/null 2>&1 || fail 'invalid merged TOML settings'
  yq -p toml -o toml 'select(tag == "!!map")' "$work/original" > "$work/normalized" 2>/dev/null || fail 'invalid local TOML settings'
  if "$existed" && cmp -s "$work/normalized" "$work/new"; then
    exit 0
  fi
fi

mkdir -p -- "$(dirname -- "$target")"
staged=$(mktemp "$(dirname -- "$target")/.home-manager-settings.XXXXXX")
cat "$work/new" > "$staged"

# ponytail: compare before replacing; apps with continuous writers must be closed.
if "$existed"; then
  if [[ -L "$target" || ! -f "$target" ]] || ! cmp -s "$work/original" "$target"; then
    fail 'settings changed during the merge'
  fi
  backup_dir=${XDG_STATE_HOME:-$HOME/.local/state}/home-manager/config-backups
  mkdir -p -- "$backup_dir"
  chmod 700 "$backup_dir"
  backup=$(mktemp "$backup_dir/$(basename -- "$(dirname -- "$target")")-$(basename -- "$target").XXXXXX")
  cat "$work/original" > "$backup"
else
  [[ ! -e "$target" && ! -L "$target" ]] || fail 'settings appeared during the merge'
fi
mv -- "$staged" "$target"
staged=
