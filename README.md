# Nix

NixOS with integrated Home Manager for my workstations, nix-darwin with Home
Manager for the Macs, and PowerShell profiles for Windows. To set up a machine,
follow [INSTALLATION.md](INSTALLATION.md).

## Daily use

The installed checkout lives at `~/Projects/nix`; app configs in `configs/` are
linked into place, so editing them takes effect without a rebuild. Each host
builds only from its ignored `hosts/<host>/local/` data, which the installer
writes, so always use `path:` flakes. Private shell settings go in
`~/.config/zsh/local.zsh`, outside the checkout; the shell loads it last.

```sh
nswitch            # build, show changes, ask, then switch
nupdate [INPUT]    # update flake inputs and pinned apps, check, build; no switch
npin [APP]         # Linux: bump only the apps in pins/, check, build; no switch
ninfo              # list generations
nrollback N        # Mac: switch back to generation N
nclean             # remove old generations
nsearch QUERY      # search packages and options
ndesktop [NAME]    # Linux: show or pick the compositor for the next boot
mup                # upgrade Mise tools; mise install after a switch
fup                # Linux: install firmware updates
brew upgrade       # Mac, in Terminal.app: upgrade apps; add --greedy for Office
pull-projects      # fast-forward every clean repo in ~/Projects
```

`nix-workstation COMMAND --help` explains each alias. A macOS update can reset
`/etc/zshrc`; run `nswitch` again.

To update, run `git pull`, `nupdate`, then `nswitch`, and commit and push
`flake.lock` and `pins/_sources`; other machines then run `pull-projects` and
`nswitch`. `nupdate` and `npin` never ask or switch, so an agent can run them.

On Windows, PowerShell on vm and desktop has `nswitch`, `nupdate` and `mup`;
the first two run `windows\apply.ps1`, `nupdate` with `-Update`, which upgrades
winget and Mise first and applies at once. basic runs
`~\Projects\nix\windows\apply.ps1` directly.

Roll back with `nh os rollback` or an older generation in the boot menu; on a
Mac, `nrollback N` leaves apps and macOS settings as they are. Rollback
restores the system, not files in your home folder.

## Develop

```sh
nix develop path:.
uv sync --locked
just check
```

`just --list` shows the other recipes. Build a host without activating it with
`nh os build`.

[docs/PLAN.md](docs/PLAN.md) holds the open work.
