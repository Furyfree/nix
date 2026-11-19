# Nix workstation

This is my public, personal workstation configuration. NixOS runs the desktop
and the laptop whole. Everywhere else this repository gives the terminal, the
app configs and an app list in the system's own package manager, and the rest
is a checklist: nix-darwin on the Macs, Home Manager on its own on the Ubuntu
work laptop, and PowerShell profiles on Windows. I want repeatable installs
and updates, shared app preferences and rollback where the system has it.
`docs/PLAN.md` holds the open work.

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
- Ubuntu: IT owns the kernel and its own agents; never touch them.
- Windows: never uninstall apps, save registry values before their first
  import, keep Secure Boot, TPM, Defender, the firewall, UAC and Windows Update
  on, and keep BitLocker recovery keys out of output and logs.

## Approach

Use pinned upstream NixOS, nix-darwin and Home Manager modules and native
tools. This is a personal workstation configuration, not another provisioning
framework. Never make another system imitate NixOS; what a system cannot do
natively goes on its checklist.
Edit configuration in this repository and deploy through Git and a rebuild
from the machine's checkout. Use SSH for read-only
inspection and approved deployment/rebuild commands, never direct configuration
patches on machines.

Setups on one system share one list and differ by whole add-ons. A must-have
is what a setup's purpose needs, and gets fixed when it breaks; a nice-to-have
comes with a shared list and is dropped there when it breaks.

A file is one topic every machine of its system takes, or one purpose some
machines add. What one machine alone has is lines in its host file. Split a
file only when a machine must not get part of it; a topic under 15 lines folds
into its nearest topic.

Hyprland and Niri share one desktop. Change and check the running one
(`$XDG_CURRENT_DESKTOP`) first, then ask whether to port the change to the
other. Port it when the other has a direct equivalent; when it needs testing
there, open an issue titled after that compositor.

Each fact lives once: in config or code where it can, with docs pointing to it.
Docs and comments state no current versions or status; open work lives in
`docs/PLAN.md` or GitHub issues, and a workaround links its issue.

## Map

- `flake.nix`: inputs, every system's outputs and the development tools.
- `nixos/`, `darwin/`, `ubuntu/`, `windows/`: one folder per system, with its
  own `AGENTS.md` for its map and checks and a README for its setup. Each keeps
  its machine data in an ignored `local/`; NixOS one per host.
- `home-manager/`: the Home Manager code systems share. NixOS, the Macs and
  Ubuntu take the terminal and app configs in `common.nix`, the SSH key sets
  in `ssh.nix` and the live-link helpers `config.lib.workstation.link` and
  `script`. NixOS and Ubuntu take the Noctalia desktop in `linux.nix` and Niri
  in `niri.nix`. `cli-tools.nix` is the Nix CLI list, which the Mac's brews and
  Windows' `windows-tools.toml` mirror.
- `configs/`: native app preferences, linked live from the checkout; keep the
  checkout at `~/Projects/nix`. SSH hosts stay in private 1Password documents,
  never here. `configs/hypr/hosts/<host>.lua` and `configs/niri/hosts/<host>.kdl`
  hold each host's monitors, workspaces and keys. `configs/bin` links to `bin/`
  until every machine has switched past the move.
- `bin/`: our own scripts, linked into `~/.local/bin`: `nix-workstation` (the
  `n*` aliases), `pull-projects`, `launch`, `agent-brave`, and `windows-vm`,
  which `windows-vm.nix` builds for NixOS and Ubuntu.
- `justfile`: the local gates.

## Ways to hurt yourself

The installer erases the selected disk. Use disposable targets for installation
trials and temporary checkouts for tests. Require detected machine data for host
builds; pre-install fixtures belong only in temporary checkouts.
Native desktop tools keep live state outside the checkout. Do not import whole
application-data directories or overwrite GUI state while adding app preferences.

## Verify

Use `nix develop` for tooling. Run focused checks while editing and `just check`
for the repository gate; it also parses the Windows scripts and profiles.
Evaluate active flake outputs and build system changes without activation.
To update, run `nix-workstation update` (or `pin` for the apps in
`nixos/pins/`), report its summary and stop; I run `nswitch`.
Installation, login, sleep/resume and rollback need machine checks; a successful
build does not establish those behaviors.
