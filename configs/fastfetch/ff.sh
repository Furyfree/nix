#!/bin/sh
# Shell rows for config.jsonc; fastfetch's Lua cannot read files or run commands.

os_age() {
  # NixOS writes machine-id on first boot after installation.
  birth=$(stat -c %W /etc/machine-id 2>/dev/null) || birth=
  now=$(date +%s 2>/dev/null) || now=
  case "$birth:$now" in
    *[!0-9:]* | :* | *:)
      printf 'not recorded'
      return
      ;;
  esac
  if [ "$birth" -le 0 ] || [ "$birth" -gt "$now" ]; then
    printf 'not recorded'
    return
  fi
  days=$(((now - birth) / 86400))
  if [ "$days" -eq 0 ]; then
    printf '<1 day (estimate)'
  elif [ "$days" -eq 1 ]; then
    printf '~1 day'
  else
    printf '~%s days' "$days"
  fi
}

noctalia_label() {
  # Match the command path: the Nix wrapper renames the process. Installation
  # alone does not establish that this shell is running.
  pgrep -u "$(id -u)" -f '/bin/noctalia( |$)' >/dev/null 2>&1 || return
  # `noctalia --version` prints "noctalia v5.1.0"; keep the plain label otherwise.
  version=$(noctalia --version 2>/dev/null)
  version=${version#noctalia v}
  case $version in
    '' | *[!0-9.]*) printf 'Noctalia (desktop shell)' ;;
    *) printf 'Noctalia %s (desktop shell)' "$version" ;;
  esac
}

case ${1-} in
  age) os_age ;;
  noctalia) noctalia_label ;;
  *)
    printf '%s\n' 'usage: ff.sh age|noctalia' >&2
    exit 2
    ;;
esac
