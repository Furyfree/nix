if whence -p eza >/dev/null 2>&1; then
  # ls with ls's flags, drawn by eza, which reads -t, -S, -X, -U and others
  # differently: https://github.com/eza-community/eza/issues/1573
  # Flags eza has no match for, and long options, run the real ls.
  # NixOS's /etc/zshrc aliases ls, and an alias runs before a function.
  unalias ls 2>/dev/null
  function ls {
    emulate -L zsh

    local -a args=("$@") opts files
    local arg flag sort=name field=modified reverse=0
    while (( $# )); do
      arg=$1
      shift
      if [[ $arg == -- ]]; then
        files+=("$@")
        break
      fi
      if [[ $arg != -?* ]]; then
        files+=("$arg")
        continue
      fi
      if [[ $arg == --* ]]; then
        command ls "${args[@]}"
        return
      fi
      for flag in ${(s::)arg#-}; do
        case $flag in
          [lAdRi1xZ]) opts+=(-$flag) ;;
          # ls -a also lists . and .., which eza shows for -aa.
          a) opts+=(-a -a) ;;
          r) reverse=1 ;;
          t) sort=$field ;;
          S) sort=size ;;
          X) sort=extension ;;
          U) sort=none ;;
          c|u)
            [[ $flag == c ]] && field=changed || field=accessed
            opts+=(--$field)
            [[ $sort == modified ]] && sort=$field
            ;;
          n) opts+=(-l -n) ;;
          g) opts+=(-l --no-user) ;;
          o) opts+=(-l) ;;
          [Fp]) opts+=(--classify=always) ;;
          L) opts+=(-X) ;;
          # eza already shows readable sizes, no group, and a natural sort.
          [hGCvk]) ;;
          *)
            command ls "${args[@]}"
            return
            ;;
        esac
      done
    done

    case $sort in
      name) opts+=(--group-directories-first) ;;
      # ls lists newest and largest first; eza sorts the other way.
      modified|changed|accessed|size)
        opts+=(-s "$sort")
        (( reverse ^= 1 ))
        ;;
      *) opts+=(-s "$sort") ;;
    esac
    (( reverse )) && opts+=(-r)
    command eza --icons=auto "${opts[@]}" -- "${files[@]}"
  }

  alias ll='eza -la --header --icons=auto --group-directories-first'
  alias la='eza -a --icons=auto --grid --group-directories-first'
  alias lt='eza --tree --icons=auto --group-directories-first'
else
  alias ll='ls -lah'
  alias la='ls -a'
fi
