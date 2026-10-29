#!/bin/bash
# OmniWM's workspaces in the menu bar: 1–5 always, 6–9 only while they hold
# windows, and the active one as a dingbat digit. Clicking opens a menu that
# switches workspace. Needs OmniWM's IPC (general.ipcEnabled in its
# settings.toml); `--once` prints one update and stops.
#
# Each update ends with ~~~ and is written in one piece, so SwiftBar swaps the
# whole title at once instead of showing its own name in between.
#
# <swiftbar.title>OmniWM workspaces</swiftbar.title>
# <swiftbar.type>streamable</swiftbar.type>
# <swiftbar.useTrailingStreamSeparator>true</swiftbar.useTrailingStreamSeparator>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>
# <swiftbar.hideSwiftBar>true</swiftbar.hideSwiftBar>

omniwmctl=/opt/homebrew/bin/omniwmctl

# One update. The query lists workspaces in number order, so the row is the
# number; WORKSPACE is the display name and COUNTS holds the window total.
render() {
  local table update
  if table=$("$omniwmctl" query workspaces --format tsv 2>/dev/null); then
    update=$(awk -F '\t' -v ctl="$omniwmctl" '
      BEGIN { split("❶ ❷ ❸ ❹ ❺ ❻ ❼ ❽ ❾", mark, " ") }
      NR == 1 { next }
      {
        n = NR - 1
        current = $5 == "yes"
        match($7, /total=[0-9]+/)
        total = substr($7, RSTART + 6, RLENGTH - 6) + 0
        if (n > 5 && total == 0 && !current) next
        label = $2
        if (current) label = label ~ /^[0-9]+$/ ? mark[n] : "‹" label "›"
        title = title (title == "" ? "" : " ") label
        menu = menu sprintf("Workspace %s | bash=%s param1=command param2=switch-workspace param3=%d terminal=false\n", $2, ctl, n)
      }
      END { print title; print "---"; printf "%s", menu }' <<<"$table")
  else
    update=$'⚠︎ OmniWM\n---\nOmniWM is not running or its IPC is off'
  fi
  printf '%s\n~~~\n' "$update"
}

render
[[ $1 == --once ]] && exit
"$omniwmctl" subscribe workspace-bar,active-workspace --no-send-initial --reconnect --format ndjson |
  while read -r _; do render; done
