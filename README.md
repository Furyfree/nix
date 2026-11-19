# Nix

My workstations. NixOS runs the whole machine; elsewhere this repository gives
the terminal, the app configs and an app list, and the rest is a checklist.

| Machine | Setup |
|---|---|
| NixOS desktop and laptop | [nixos/README.md](nixos/README.md) |
| Macs, through nix-darwin | [darwin/README.md](darwin/README.md) |
| Ubuntu work laptop | [ubuntu/README.md](ubuntu/README.md) |
| Windows desktop, VM and Basic | [windows/README.md](windows/README.md) |

## Daily use

The installed checkout lives at `~/Projects/nix`; app configs in `configs/` are
linked into place, so editing them takes effect without a rebuild. Each machine
builds only from its system's ignored `local/` data, so always use `path:`
flakes. Private shell settings go in
`~/.config/zsh/local.zsh`, outside the checkout; the shell loads it last.

```sh
nswitch            # build, show changes, ask, then switch
nupdate [INPUT]    # update flake inputs and pinned apps, check, build; no switch
npin [APP]         # NixOS: bump only the apps in nixos/pins/, check, build
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
`flake.lock` and `nixos/pins/_sources`; other machines then run `pull-projects` and
`nswitch`. `nupdate` and `npin` never ask or switch, so an agent can run them.

On Ubuntu, `nswitch` switches Home Manager, then `ubuntu/apps.sh` installs the
apps that are missing; `git pull` brings `flake.lock` from NixOS, so `nupdate`
and `npin` run on NixOS only.

On Windows, PowerShell on vm and desktop has `nswitch`, `nupdate` and `mup`;
the first two run `windows\apply.ps1`, `nupdate` with `-Update`, which upgrades
winget and Mise first and applies at once. basic runs
`~\Projects\nix\windows\apply.ps1` directly.
In NixOS in WSL, the aliases above work without Snapper.

Roll back with `nh os rollback` or an older generation in the boot menu; on a
Mac, `nrollback N` leaves apps and macOS settings as they are. Rollback
restores the system, not files in your home folder.

## SSH keys

Every machine. In 1Password, sign in, then in Settings → Developer turn on the
SSH agent and the CLI integration. The keys stay in 1Password; these public
halves only tell SSH which key a host gets, and the profile's private document
lists its hosts:

```bash
op item get n6imsp5vfs5nmlt5rmxgs6zdci --fields "label=public key" >~/.ssh/github.pub
git config --file ~/.config/git/local user.signingkey ~/.ssh/github.pub
```

Personal machines:

```bash
op item get 3ppqekfxnmjtg2iapnr5d7gewi --fields "label=public key" >~/.ssh/homelab.pub
op item get 3psgdyql5u5zlpamsfc4xr7cbu --fields "label=public key" >~/.ssh/personal.pub
op document get 3223bqk2tzqdut7gdhiqjyqj34 --out-file ~/.ssh/local.conf
```

Work machines, with the work commit email:

```bash
op item get cwlhpt5lcyn3dsuyx4wyms2ama --fields "label=public key" >~/.ssh/work.pub
op document get npl7xfsvir6kbq7jvptugkczhm --out-file ~/.ssh/local.conf
git config --file ~/.config/git/local user.email <work email>
```

Then `gh auth login`, and switch this checkout to SSH, since it was cloned
over HTTPS:
`git -C ~/Projects/nix remote set-url origin git@github.com:Furyfree/nix.git`

## Develop

```sh
nix develop path:.
just check
```

`just --list` shows the other recipes. Build a host without activating it with
`nh os build`.

[docs/PLAN.md](docs/PLAN.md) holds the open work.
