export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

export ZDOTDIR="$XDG_CONFIG_HOME/zsh"

# Agents write bash, so run their commands in bash; macOS has only /bin/bash.
agent_bash=/run/current-system/sw/bin/bash
[[ -x $agent_bash ]] || agent_bash=/bin/bash
export CLAUDE_CODE_SHELL=$agent_bash GROK_SHELL=$agent_bash
# Codex runs commands as "zsh -lc" and has no shell setting; hand them to bash.
if [[ -n $CODEX_TOOL_CALL_ID && -n $ZSH_EXECUTION_STRING && ! -o interactive ]]; then
  exec "$agent_bash" -c "$ZSH_EXECUTION_STRING"
fi
unset agent_bash
