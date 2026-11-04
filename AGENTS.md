# Nix workstation

This is my public, personal workstation configuration for Linux, macOS and
Windows where possible. I want repeatable installs and updates, shared desktop
preferences and generation rollback.

My Linux workstations run NixOS with integrated Home Manager. Extend compatible
user configuration through Home Manager to macOS and WSL, one tool at a time.
Every Mac gets nix-darwin with Home Manager from the one `macos` host; the
personal Mac runs it and the work Mac waits for IT. WSL and Windows are future
targets. `docs/PLAN.md` moves the Windows setup here from win-setup, which
stays in use until then.

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
- "Work" may name the work Mac and its SSH key set, never the employer, its
  apps, VPN, servers or Git identity.

## Approach

Use pinned upstream NixOS, nix-darwin and Home Manager modules and native
tools. This is a personal workstation configuration, not another provisioning
framework.
Edit configuration in this repository and deploy through Git and a rebuild
from the machine's checkout. Use SSH for read-only
inspection and approved deployment/rebuild commands, never direct configuration
patches on machines.

## Map

- `flake.nix`: inputs, system outputs and development tools.
- `system.nix`, `components/`: shared system settings; import new components
  through `system.nix`.
- `darwin/`: nix-darwin for every Mac. `default.nix` is the base,
  `common.nix` the shared Homebrew apps and tools, and `personal.nix` or
  `work.nix` the profile a Mac's `local/user.nix` imports.
- `home/`, `configs/`: Home Manager integration and links versus native
  application preferences. `common.nix` holds what every platform shares,
  `linux.nix` and `darwin.nix` the platform parts, and `ssh.nix` the
  personal or work SSH key set a host picks. SSH hosts stay in private
  1Password documents, never here. Keep the checkout at `~/Projects/nix` for
  these links.
- `hosts/`: tracked host exceptions; ignored `hosts/<host>/local/` holds detected
  hardware and installation data, and on macOS `user.nix` with the account
  and profile.
  Shared policy belongs above it.
- `configs/hypr/hosts/<host>.lua`: per-host monitors, workspaces and keys,
  linked as `~/.config/hypr/host.lua` by `hosts/<host>/home.nix`.
- `INSTALLATION.md`: NixOS install steps and the Mac's `local/user.nix`;
  update it with installer or first-boot changes.
- `scripts/install.py`: installer launcher; `scripts/nixos_setup/` holds the
  wizard, storage, configuration, credential and installation modules.
- `tests/`, `justfile`: installer behavior checks, one file per module, and
  local gates.

## Ways to hurt yourself

The installer erases the selected disk. Use disposable targets for installation
trials and temporary checkouts for tests. Require detected machine data for host
builds; pre-install fixtures belong only in temporary checkouts.
Native desktop tools keep live state outside the checkout. Do not import whole
application-data directories or overwrite GUI state while adding app preferences.

## Verify

Use `nix develop` for tooling. Run focused checks while editing and `just check`
for the repository gate. Evaluate active flake outputs and build system changes
without activation. Installation, login, sleep/resume and rollback need machine
checks; a successful build does not establish those behaviors.
