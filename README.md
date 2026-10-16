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
nswitch                                  # build and switch, between Snapper snapshots
nix flake update --flake "$NH_FLAKE"     # update pinned inputs, then nswitch
mise install                             # after a rebuild; mise upgrade for tool updates
pull-projects                            # fast-forward every clean repo in ~/Projects
```

Roll back with `sudo nixos-rebuild boot --rollback` and a reboot, or pick an
older generation in the boot menu. Rollback restores the system, not files in
your home folder.

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
