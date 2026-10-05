y() {
  emulate -L zsh

  if ! whence -p yazi >/dev/null 2>&1; then
    print -u2 -- 'y: yazi is not installed'
    return 127
  fi

  local tmp cwd result=0
  tmp="$(command mktemp "${TMPDIR:-/tmp}/yazi-cwd.XXXXXXXXXX")" || return

  {
    command yazi "$@" --cwd-file="$tmp"
    result=$?
    if (( result == 0 )); then
      # Read the entire path, including any embedded newlines.
      IFS= read -r -d '' cwd < "$tmp" || true
      if [[ -n $cwd && $cwd != $PWD ]]; then
        if [[ $cwd == /* && -d $cwd ]]; then
          builtin cd -- "$cwd"
          result=$?
        else
          print -u2 -- "y: invalid directory returned by yazi: $cwd"
          result=1
        fi
      fi
    fi
  } always {
    command rm -f -- "$tmp"
  }
  return "$result"
}

croot() {
  emulate -L zsh

  if (( $# != 0 )); then
    print -u2 -- 'usage: croot'
    return 2
  fi

  local root
  root="$(command git rev-parse --show-toplevel)" || return
  builtin cd -- "$root"
}

copypath() {
  emulate -L zsh
  setopt pipefail

  if (( $# > 1 )); then
    print -u2 -- 'usage: copypath [file-or-directory]'
    return 2
  fi

  local target="${1-$PWD}"
  if [[ ! -e $target && ! -L $target ]]; then
    print -u2 -- "copypath: path does not exist: $target"
    return 1
  fi
  print -rn -- "${target:A}" | copy
}

copy() {
  emulate -L zsh
  setopt pipefail

  local -a clipboard
  local file

  case "$OSTYPE" in
    darwin*)
      if command -v pbcopy >/dev/null 2>&1; then
        clipboard=(pbcopy)
      fi
      ;;
    linux*)
      if [[ -n ${WAYLAND_DISPLAY-} ]] && command -v wl-copy >/dev/null 2>&1; then
        clipboard=(wl-copy)
      elif [[ -n ${DISPLAY-} ]] && command -v xclip >/dev/null 2>&1; then
        clipboard=(xclip -selection clipboard)
      fi
      ;;
  esac

  if (( ${#clipboard} == 0 )); then
    print -u2 -- 'copy: no supported clipboard tool/session (pbcopy, wl-copy, or xclip)'
    return 1
  fi

  # Check every file before starting a clipboard write.
  for file in "$@"; do
    if [[ ! -f "$file" || ! -r "$file" ]]; then
      print -u2 -- "copy: not a readable regular file: $file"
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
}

clip-paste() {
  emulate -L zsh

  if (( $# != 0 )); then
    print -u2 -- 'usage: clip-paste (prints clipboard contents)'
    return 2
  fi

  case "$OSTYPE" in
    darwin*)
      if command -v pbpaste >/dev/null 2>&1; then
        command pbpaste
        return
      fi
      ;;
    linux*)
      if [[ -n ${WAYLAND_DISPLAY-} ]] && command -v wl-paste >/dev/null 2>&1; then
        command wl-paste --no-newline
        return
      elif [[ -n ${DISPLAY-} ]] && command -v xclip >/dev/null 2>&1; then
        command xclip -selection clipboard -out
        return
      fi
      ;;
  esac

  print -u2 -- 'clip-paste: no supported clipboard tool/session (pbpaste, wl-paste, or xclip)'
  return 1
}
