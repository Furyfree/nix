#!/usr/bin/env bash
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT
bash_bin=$(command -v bash)
zsh_bin=$(command -v zsh)

mkdir -p "$test_dir/home with spaces" "$test_dir/bin" "$test_dir/config/zsh"
ln -s "$repo/configs/bash" "$test_dir/config/bash"
ln -s "$repo/configs/bash/.bashrc" "$test_dir/home with spaces/.bashrc"
ln -s "$repo/configs/bash/.bash_profile" "$test_dir/home with spaces/.bash_profile"
ln -s "$repo/configs/zsh/.zshenv" "$test_dir/home with spaces/.zshenv"
ln -s "$repo/configs/zsh/.zshrc" "$test_dir/config/zsh/.zshrc"
ln -s "$repo/configs/zsh/.zprofile" "$test_dir/config/zsh/.zprofile"
ln -s "$repo/configs/zsh/conf.d" "$test_dir/config/zsh/conf.d"
# Keep installed integrations and their downloads outside these startup checks.
for utility in mkdir chmod mv; do
  ln -s "$(command -v "$utility")" "$test_dir/bin/$utility"
done

# shellcheck disable=SC2016 # The child shell expands these expressions.
env -i HOME="$test_dir/home with spaces" PATH="$test_dir/bin" TERM=dumb \
  XDG_CONFIG_HOME="$test_dir/config" XDG_CACHE_HOME="$test_dir/cache" \
  XDG_DATA_HOME="$test_dir/data" XDG_STATE_HOME="$test_dir/state" \
  "$bash_bin" --noprofile --norc -ic '
    BASH_COMPLETION_VERSINFO=(test)
    source "$HOME/.bash_profile" || exit
    declare -F copy croot >/dev/null || exit
    before=${PROMPT_COMMAND[*]}
    source "$HOME/.bashrc" || exit
    [[ ${PROMPT_COMMAND[*]} == "$before" ]] || exit 1
    [[ $PATH == "$HOME/.local/bin:"* ]] || exit 1
    unset HISTFILE
  ' < /dev/null

# shellcheck disable=SC2016 # The child shell expands these expressions.
env -i HOME="$test_dir/home with spaces" PATH="$test_dir/bin" TERM=dumb \
  XDG_CONFIG_HOME="$test_dir/config" XDG_CACHE_HOME="$test_dir/cache" \
  XDG_DATA_HOME="$test_dir/data" XDG_STATE_HOME="$test_dir/state" \
  "$zsh_bin" -d -f -ic '
    source "$HOME/.zshenv" || exit
    source "$ZDOTDIR/.zprofile" || exit
    source "$ZDOTDIR/.zshrc" || exit
    (( $+functions[copy] && $+functions[croot] && $+functions[compdef] )) || exit 1
    [[ $ZDOTDIR == "$XDG_CONFIG_HOME/zsh" && -e "$XDG_CACHE_HOME/zsh/zcompdump" ]] || exit 1
    unset HISTFILE
  ' < /dev/null

[[ $(stat -c %a "$test_dir/state/bash") == 700 ]]
[[ $(stat -c %a "$test_dir/state/zsh") == 700 ]]
printf '%s\n' 'Shell startup checks passed.'
