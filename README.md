# Nix

NixOS with integrated Home Manager for my workstations: `desktop`, `laptop` and
the `nixos-test` machine. To set up a machine, follow
[INSTALLATION.md](INSTALLATION.md).

## Daily use

The installed checkout lives at `~/Projects/nix`; app configs in `configs/` are
linked into place, so editing them takes effect without a rebuild. Each host
builds only from its ignored `hosts/<host>/local/` data, which the installer
writes, so always use `path:` flakes.

```sh
nswitch            # build, show changes, ask, then switch between Snapper snapshots
nupdate [INPUT]    # update pinned inputs, run just check, then nswitch
ninfo              # list system generations
nclean             # remove old generations; keeps the boot menu's 10
nsearch QUERY      # search packages and options
mup                # upgrade Mise tools; mise install after a rebuild
fup                # install firmware updates
pull-projects      # fast-forward every clean repo in ~/Projects
```

The aliases run `nix-workstation`, linked from `configs/bin`;
`nix-workstation --help` lists its commands and `nix-workstation COMMAND --help`
explains one. On a machine built before the script existed, the link and
aliases appear after one switch run from the checkout:

```sh
~/Projects/nix/configs/bin/nix-workstation switch
```

Roll back with `nh os rollback`, or pick an older generation in the boot menu.
Rollback restores the system, not files in your home folder.

## Develop

```sh
nix develop path:.
uv sync --locked
just check
```

`just` lists the commands: `just wizard` previews the installer without
changes, `just build-iso` and `just burn` make the USB stick, and
`just format` formats Python and Nix files. Build a host without activating it
with `nh os build`.

[docs/PLAN.md](docs/PLAN.md) holds the open work.
