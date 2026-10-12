if [[ -o zle && -t 0 ]] && command -v fzf >/dev/null 2>&1; then
  () {
    local fzf_source
    fzf_source="$(command fzf --zsh)" || return

    local previewer
    if whence -p bat >/dev/null 2>&1; then
      previewer=bat
    elif whence -p batcat >/dev/null 2>&1; then
      previewer=batcat
    fi

    if [[ -n $previewer ]]; then
      export FZF_CTRL_T_OPTS="${FZF_CTRL_T_OPTS-}
        --preview 'if [ -d {} ]; then command ls -A -- {}; else command $previewer --style=numbers --color=always --paging=never --line-range=:300 -- {}; fi'
        --bind 'ctrl-/:toggle-preview'"
    fi

    # fzf actions run in a separate shell, where our copy function is unavailable.
    local clipboard_copy
    case "$OSTYPE" in
      darwin*)
        command -v pbcopy >/dev/null 2>&1 && clipboard_copy='pbcopy'
        ;;
      linux*)
        if [[ -n ${WAYLAND_DISPLAY-} ]] && command -v wl-copy >/dev/null 2>&1; then
          clipboard_copy='wl-copy'
        elif [[ -n ${DISPLAY-} ]] && command -v xclip >/dev/null 2>&1; then
          clipboard_copy='xclip -selection clipboard'
        fi
        ;;
    esac

    if [[ -n $clipboard_copy ]]; then
      export FZF_CTRL_R_OPTS="${FZF_CTRL_R_OPTS-}
        --bind 'ctrl-y:execute-silent(printf %s {2..} | command $clipboard_copy)+abort'
        --header 'Ctrl-Y: copy focused command to clipboard'"
    fi

    eval "$fzf_source"

    # Leave Tab to our completion module and fzf-tab.
    bindkey '^I' expand-or-complete
  }
fi
