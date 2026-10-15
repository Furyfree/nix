# Nix workstation

This is my public, personal workstation configuration for Linux, macOS and
Windows where possible. I want repeatable installs and updates, shared desktop
preferences and generation rollback.

Finish the full NixOS/Linux setup with integrated Home Manager and move onto it
first. Then extend compatible user configuration through Home Manager to WSL
and macOS. Those are future targets, not working support today. Migrate tools
one at a time; keep Fedora, Nimbus and Chezmoi until their replacements work.

## What must not break

- Keep shared workstation policy separate from host hardware and installation
  data. Use the installer-selected account rather than hard-coded usernames.
- Keep app preferences native and writable through checkout links. Native tools
  own credentials, generated colors, GUI overrides and downloaded plugins;
  keep that runtime state outside Git and the Nix store.
- Preserve disk-selection confirmation, existing user files and rollback.
  Builds and configuration evaluation must not activate a system.
- Keep secrets, credentials and private machine records out of this public repo.
  Use safe examples in documentation and tests.

## Approach

Use pinned upstream NixOS/Home Manager modules and native tools. This is a
personal workstation configuration, not another provisioning framework.
During setup and testing, edit configuration in this repository and deploy
through Git and a rebuild from the machine's checkout. Use SSH for read-only
inspection and approved deployment/rebuild commands, never direct configuration
patches on machines.

## Map

- `flake.nix`: inputs, system outputs and development tools.
- `system.nix`, `components/`: shared system settings; import new components
  through `system.nix`.
- `home.nix`, `configs/`: Home Manager integration and links versus native
  application preferences. Keep the checkout at `~/Projects/nix` for these links.
- `hosts/`: tracked host exceptions; ignored `hosts/<host>/local/` holds detected
  hardware and installation data. Shared policy belongs above it.
- `scripts/install.py`: installer launcher; `scripts/nixos_setup/` holds the
  wizard, storage, configuration, credential and installation modules.
- `scripts/migrations/`: one-time upgrades for existing checkouts, without activation.
- `tests/`, `justfile`: installer behavior checks, one file per module, and
  local gates.

## Ways to hurt yourself

The installer erases the selected disk. Use disposable targets for installation
trials and temporary checkouts for tests. Require detected machine data for host
builds; pre-install fixtures belong only in temporary checkouts.
Native desktop tools keep live state outside the checkout. Do not import whole
application-data directories or overwrite GUI state while migrating preferences.

## Verify

Use `nix develop` for tooling. Run focused checks while editing and `just check`
for the repository gate. Evaluate active flake outputs and build system changes
without activation. Installation, login, sleep/resume and rollback need machine
checks; a successful build does not establish those behaviors.
