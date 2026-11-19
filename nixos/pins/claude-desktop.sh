#!/usr/bin/env bash
# Claude Desktop from Anthropic's signed apt repository, checked against
# claude-desktop.asc (31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE).
# Without arguments, print the newest version; nvfetcher.toml reads it.
# With VERSION HASH, fail unless HASH is the signed SHA256 of that version's
# .deb; nix-workstation checks nvfetcher's download with it.
set -euo pipefail

repo=https://downloads.claude.ai/claude-desktop/apt/stable
key=$(dirname -- "$(realpath -- "$0")")/claude-desktop.asc
temporary=$(mktemp -d)
trap 'rm -rf -- "$temporary"' EXIT
export GNUPGHOME=$temporary

curl -fsSL "$repo/dists/stable/InRelease" -o "$temporary/InRelease"
gpg --quiet --dearmor --output "$temporary/key.gpg" "$key"
gpgv --quiet --keyring "$temporary/key.gpg" --output "$temporary/Release" "$temporary/InRelease"

# The Packages index must match the SHA256 that the signed Release lists.
curl -fsSL "$repo/dists/stable/main/binary-amd64/Packages" -o "$temporary/Packages"
expected=$(awk '/^SHA256:/ { s = 1; next } /^[^ ]/ { s = 0 }
  s && $3 == "main/binary-amd64/Packages" { print $1 }' "$temporary/Release")
[[ -n $expected ]] || { echo 'claude-desktop.sh: no Packages entry in Release' >&2; exit 1; }
echo "$expected  $temporary/Packages" | sha256sum --check --quiet --strict

# One "version sha256" line per claude-desktop package.
awk -v RS= '/(^|\n)Package: claude-desktop\n/ {
  version = sha = ""
  n = split($0, lines, "\n")
  for (i = 1; i <= n; i++) {
    if (lines[i] ~ /^Version: /) version = substr(lines[i], 10)
    if (lines[i] ~ /^SHA256: /) sha = substr(lines[i], 9)
  }
  print version, sha
}' "$temporary/Packages" >"$temporary/versions"

if (($# == 0)); then
  cut -d ' ' -f 1 "$temporary/versions" | sort -V | tail -n 1
elif (($# == 2)); then
  sha=$(awk -v v="$1" '$1 == v { print $2 }' "$temporary/versions")
  [[ -n $sha ]] || { echo "claude-desktop.sh: $1 is not in the signed index" >&2; exit 1; }
  signed=$(nix hash convert --hash-algo sha256 --to sri "$sha")
  [[ $2 == "$signed" ]] || {
    echo "claude-desktop.sh: $1 downloaded as $2, but the signed index says $signed" >&2
    exit 1
  }
else
  echo 'usage: claude-desktop.sh [VERSION HASH]' >&2
  exit 2
fi
