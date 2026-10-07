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
nix --extra-experimental-features 'nix-command flakes' flake check --no-build --no-write-lock-file path:/home/user/Projects/nix
nix --extra-experimental-features 'nix-command flakes' build --no-link path:/home/user/Projects/nix#nixosConfigurations.nixos-test.config.system.build.toplevel
```

Build without activation. Follow the installation guide for deployment,
Snapper snapshots and rollback; its disk identifiers belong to the test machine.

- [Installation and recovery](docs/INSTALLATION.md)
- [Boot, installer and migration plan](docs/PLAN.md)
