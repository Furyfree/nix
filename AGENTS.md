# Nix workstation

This is my public, personal workstation configuration for Linux, macOS and
Windows where possible. I want repeatable installs and updates, shared desktop
preferences and generation rollback.

My Linux workstations run NixOS with integrated Home Manager, and every Mac runs
nix-darwin with Home Manager from the one `macos` host. Extend compatible user
configuration through Home Manager one tool at a time. `docs/PLAN.md` holds the
open work.

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
- Macs: never remove apps (Homebrew cleanup stays off), save settings before
  the first switch, keep FileVault, SIP, Gatekeeper and the firewall on, and
  leave what IT manages off the work Mac.

## Approach

Use pinned upstream NixOS, nix-darwin and Home Manager modules and native
tools. This is a personal workstation configuration, not another provisioning
framework.
Edit configuration in this repository and deploy through Git and a rebuild
from the machine's checkout. Use SSH for read-only
inspection and approved deployment/rebuild commands, never direct configuration
patches on machines.

Hyprland and Niri share one desktop. Change and check the running one
(`$XDG_CURRENT_DESKTOP`) first, then ask whether to port the change to the
other. Port it when the other has a direct equivalent; when it needs testing
there, open an issue titled after that compositor.

Each fact lives once: in config or code where it can, with docs pointing to it.
Docs and comments state no current versions or status; open work lives in
`docs/PLAN.md` or GitHub issues, and a workaround links its issue.

## Map

- `flake.nix`: inputs, system outputs and development tools.
- `system.nix`, `components/`: shared system settings; import new components
  through `system.nix`.
- `darwin/`: nix-darwin for every Mac: a shared base and one profile per Mac,
  which its `local/user.nix` imports.
- `home/`, `configs/`: Home Manager integration and links versus native
  application preferences: shared parts in `common.nix`, platform and profile
  parts beside it. SSH hosts stay in private 1Password documents, never here.
  Keep the checkout at `~/Projects/nix` for these links.
- `hosts/`: tracked host exceptions; ignored `hosts/<host>/local/` holds detected
  hardware and installation data, on NixOS an optional `desktop.nix` that
  picks the compositor, and on macOS `user.nix` with the account and profile.
  Shared policy belongs above it.
- `configs/hypr/hosts/<host>.lua`, `configs/niri/hosts/<host>.kdl`: per-host
  monitors, workspaces and keys, linked as `host.lua` or `host.kdl` by
  `home/hyprland.nix` or `home/niri.nix` after the hostname.
- `INSTALLATION.md`: NixOS install steps and the Mac's `local/user.nix`;
  update it with installer or first-boot changes.
- `scripts/install.py`: installer launcher; `scripts/nixos_setup/` holds its
  modules.
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
