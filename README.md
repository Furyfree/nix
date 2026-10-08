# Nix

NixOS and integrated Home Manager for workstations. Only `nixos-test`
is active; finish boot and the installer ISO before migrating userland.

## Develop

```sh
nix --extra-experimental-features 'nix-command flakes' develop path:.
uv sync --locked
just check
```

Run `just` to list commands, `just wizard` for the plan-only installer, and
`just format` to format Python and Nix files. Development tools and the local
`.venv` stay out of the ISO; it includes the configuration source and installer runtime.

## Check and build

```sh
cd ~/Projects/nix
nix --extra-experimental-features 'nix-command flakes' flake check --no-build --no-write-lock-file path:.
nix --extra-experimental-features 'nix-command flakes' build --no-link path:.#nixosConfigurations.nixos-test.config.system.build.toplevel
```

Build without activation. Follow the installation guide for deployment,
Snapper snapshots and rollback. The recorded host uses example disk UUIDs;
generate hardware settings before deploying it to an existing machine.

## Install

Boot the ISO in a disposable UEFI VM. The local console starts
`nixos-setup` as root. Choose a disk and username; use **Change settings** for
SSH keys or swap size. Only `nixos-test` with erase mode is supported. Enter and
confirm one password for disk encryption, root and your user, then review the
settings and type the disk's full path to authorize erasure. Installation runs
without more setup questions. Native tools handle password text outside Python,
Git and the Nix store. Reboot is optional.
`nixos-setup --dry-run` and `just wizard` skip passwords and erase authorization;
they preview without cloning or writing.

The installer needs internet access and public `main` containing these changes.
Full installation/boot VM testing is still pending.
Do not use this installer on a physical disk until that test passes.

## Installed checkout

Configuration generation clones public `main` into `~/Projects/nix` and keeps
its lock file. It replaces the selected host's hardware configuration and writes
`installation.nix` for the chosen user, public SSH key and swap/resume settings.
It keeps `configuration.nix` and `home.nix`, including custom packages.
The installed user owns the checkout and its parent directories.

After installation, review generated host changes with `git diff` and
`git status`. Passwords and private keys stay outside the repo.
From the installed checkout, build changes without activation:

```sh
cd ~/Projects/nix
nixos-rebuild build --flake path:.#nixos-test
```

To activate them, run `nixos-rebuild switch` as root with
`--flake "path:/home/<user>/Projects/nix#nixos-test"`.

- [Installation and recovery](docs/INSTALLATION.md)
- [Boot, installer and migration plan](docs/PLAN.md)
