# Nix

NixOS and integrated Home Manager for workstations. Only `nixos-test`
is supported; its output requires local machine data.

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

Build without activation. The public checkout exposes the installer and development
shell; installed host outputs require machine data. Follow the installation guide
for deployment, Snapper snapshots and rollback.

## Install

Boot the ISO on a disposable UEFI machine or in a VM. The local console starts
`nixos-setup` as root. Choose a disk and username; use **Change settings** for
SSH keys or swap size. Only `nixos-test` with erase mode is supported. Enter and
confirm one password for disk encryption, root and your user, then review the
settings and type the disk's full path to authorize erasure. Installation runs
without more setup questions. Native tools handle password text outside Python,
Git and the Nix store. Reboot is optional.
`nixos-setup --dry-run` and `just wizard` skip passwords and erase authorization;
they preview without cloning or writing.

The installer needs internet access and public `main`.
We installed from the ISO on a disposable Qotom machine, then updated the
installed repo, rebuilt with new changes and tested generation rollback. See
[boot setup and deferred tests](docs/PLAN.md#boot-and-storage).

## Installed checkout

Configuration generation clones public `main` into `~/Projects/nix` and keeps
its lock file. It writes detected hardware and `installation.nix` into ignored
`hosts/nixos-test/local/`. These files supply the chosen user, public SSH key and
swap/resume settings. Tracked configuration and custom packages stay unchanged.
The installed user owns the checkout and its parent directories.

Keep machine data local and backed up; keep passwords and private keys outside the
checkout. Use explicit `path:` flakes so Nix includes the ignored machine files.
For an existing installation with files in the old host directory, migrate once:

```sh
bash scripts/migrations/host-data.sh --dry-run
bash scripts/migrations/host-data.sh
```

Migration saves originals under `$XDG_STATE_HOME/nix/host-data-migrations`
(default `~/.local/state/nix/host-data-migrations`), checks that both layouts produce
the same system build, and builds without activation before retiring the old files.
Run it as the checkout owner; it needs Bash, Git, Nix and standard Linux tools,
not a Python environment. On failure, stop and
inspect the preserved originals and backup; do not retry over partial local data.
From the installed checkout, build changes without activation:

```sh
cd ~/Projects/nix
nixos-rebuild build --flake path:.#nixos-test
```

To activate them, run `nixos-rebuild switch` as root with
`--flake "path:/home/<user>/Projects/nix#nixos-test"`.

- [Installation and recovery](docs/INSTALLATION.md)
- [Boot, installer and migration plan](docs/PLAN.md)
