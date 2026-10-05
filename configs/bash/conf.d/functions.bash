y() {
  if ! type -P yazi >/dev/null 2>&1; then
    printf '%s\n' 'y: yazi is not installed' >&2
    return 127
  fi
  local tmp cwd result=0
  tmp="$(command mktemp "${TMPDIR:-/tmp}/yazi-cwd.XXXXXXXXXX")" || return
  if command yazi "$@" --cwd-file="$tmp"; then
    IFS= read -r -d '' cwd < "$tmp" || true
    if [[ -n $cwd && $cwd != "$PWD" ]]; then
      if [[ $cwd == /* && -d $cwd ]]; then
        builtin cd -- "$cwd" || result=$?
      else
        printf 'y: invalid directory returned by yazi: %s\n' "$cwd" >&2
        result=1
      fi
    fi
  else
    result=$?
  fi
  command rm -f -- "$tmp"
  return "$result"
}

croot() {
  if (( $# != 0 )); then
    printf '%s\n' 'usage: croot' >&2
    return 2
  fi
  local root
  root="$(command git rev-parse --show-toplevel)" || return
  builtin cd -- "$root" || return
}

copypath() (
  set -o pipefail
  if (( $# > 1 )); then
    printf '%s\n' 'usage: copypath [file-or-directory]' >&2
    return 2
  fi
  local target="${1-$PWD}" link count=0
  if [[ ! -e $target && ! -L $target ]]; then
    printf 'copypath: path does not exist: %s\n' "$target" >&2
    return 1
  fi
  [[ $target == /* ]] || target="$PWD/$target"
  # Resolve links without GNU-only realpath/readlink flags (macOS compatible).
  while :; do
    if [[ -d $target ]]; then
      builtin cd -P -- "$target" || return
      target=$PWD
      break
    fi
    builtin cd -P -- "${target%/*}/" || return
    target="${PWD%/}/${target##*/}"
    [[ -L $target ]] || break
    (( count += 1 ))
    if (( count > 40 )); then
      printf '%s\n' 'copypath: too many symbolic links' >&2
      return 1
    fi
    # The sentinel preserves trailing newlines in a link's target.
    link="$(command readlink "$target" && printf '.')" || return
    link=${link%.}
    link=${link%$'\n'}
    case $link in
      /*) target=$link ;;
      *) target="${PWD%/}/$link" ;;
    esac
  done
  # No arguments means copy reads standard input.
  # shellcheck disable=SC2119
  printf '%s' "$target" | copy
)

# shellcheck disable=SC2120
copy() (
  set -o pipefail
  local clipboard=() file
  case "$OSTYPE" in
    darwin*)
      if type -P pbcopy >/dev/null 2>&1; then clipboard=(pbcopy); fi
      ;;
    linux*)
      if [[ -n ${WAYLAND_DISPLAY-} ]] && type -P wl-copy >/dev/null 2>&1; then
        clipboard=(wl-copy)
      elif [[ -n ${DISPLAY-} ]] && type -P xclip >/dev/null 2>&1; then
        clipboard=(xclip -selection clipboard)
      fi
      ;;
  esac
  if (( ${#clipboard[@]} == 0 )); then
    printf '%s\n' 'copy: no supported clipboard tool/session (pbcopy, wl-copy, or xclip)' >&2
    return 1
  fi
  for file in "$@"; do
    if [[ ! -f $file || ! -r $file ]]; then
      printf 'copy: not a readable regular file: %s\n' "$file" >&2
      return 1
    fi
  done
  if (( $# == 0 )); then
    command "${clipboard[@]}"
  elif (( $# == 1 )); then
    command "${clipboard[@]}" < "$1"
  else
    for file in "$@"; do
      command cat < "$file" || return
    done | command "${clipboard[@]}"
  fi
)

clip-paste() {
  if (( $# != 0 )); then
    printf '%s\n' 'usage: clip-paste (prints clipboard contents)' >&2
    return 2
  fi
  case "$OSTYPE" in
    darwin*)
      if type -P pbpaste >/dev/null 2>&1; then command pbpaste; return; fi
      ;;
    linux*)
      if [[ -n ${WAYLAND_DISPLAY-} ]] && type -P wl-paste >/dev/null 2>&1; then
        command wl-paste --no-newline
        return
      elif [[ -n ${DISPLAY-} ]] && type -P xclip >/dev/null 2>&1; then
        command xclip -selection clipboard -out
        return
      fi
      ;;
  esac
  printf '%s\n' 'clip-paste: no supported clipboard tool/session (pbpaste, wl-paste, or xclip)' >&2
  return 1
}
