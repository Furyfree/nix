# Nix

NixOS and integrated Home Manager for workstations. Only `nixos-test`
is active; finish boot and the installer ISO before migrating userland.

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
