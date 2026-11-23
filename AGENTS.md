# Nix workstation

My public, personal workstation configuration, to install and update my own
machines quickly: NixOS on the desktop and laptop and in WSL, Windows on the
desktop and in a VM, Home Manager on the Ubuntu work laptop, and nix-darwin on
the family Mac and, until the Ubuntu laptop replaces it, the work Mac. Only I
use it, and machines are set up fresh: it is not for other people's PCs and
carries over no old data. GitHub issues hold the open work.

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
- "Work" may name the work machines and their SSH key set, never the employer,
  its apps, VPN, servers or Git identity.
- Macs: never remove apps (Homebrew cleanup stays off), never turn off
  FileVault, SIP, Gatekeeper or the firewall, and leave what IT manages off the
  work Mac.
- Ubuntu: IT owns the kernel and its own agents; never touch them.
- Windows: never uninstall apps, never turn off Secure Boot, TPM, Defender, the
  firewall, UAC or Windows Update, and keep BitLocker recovery keys out of
  output and logs.

## Approach

Keep it simple: fix what breaks or what I ask for. Don't add hardening,
checks, backups or docs for unlikely cases.

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

A shared config holds only what the oldest version of the app on any machine
understands; a newer option goes in that system's own include. A difference
between machines goes in the app's own include where it has one (Ghostty's and
git's, or Niri's and Hyprland's host files), else in a file merged on top.

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
GitHub issues, and a workaround links its issue.

## Map

- `flake.nix`: inputs, every system's outputs and the development tools.
- `nixos/`, `darwin/`, `ubuntu/`, `windows/`: one folder per system, with its
  own `AGENTS.md` for its map and checks and a README for its setup. Each keeps
  its machine data in an ignored `local/`; NixOS one per host.
- `home-manager/`: the Home Manager code systems share. NixOS, the Macs and
  Ubuntu take the terminal and app configs in `common.nix`, the SSH key sets
  in `ssh.nix` and the live-link helpers `config.lib.workstation.link` and
  `script`. NixOS and Ubuntu take the Noctalia desktop in `linux.nix` and Niri
  in `niri.nix`; NixOS and the personal Mac add the agents' browser in
  `agent-browser.nix`. `cli-tools.nix` is the Nix CLI list, which the Mac's
  brews mirror. Mise reads `configs/mise/config.toml` and one file per setup
  from `configs/mise/conf.d/`.
- `configs/`: native app preferences, linked live from the checkout; keep the
  checkout at `~/Projects/nix`. SSH hosts stay in private 1Password documents,
  never here. `configs/hypr/hosts/<host>.lua` and `configs/niri/hosts/<host>.kdl`
  hold each host's monitors, workspaces and keys.
- `bin/`: our own scripts, linked into `~/.local/bin`: `nix-workstation` (the
  `n*` aliases), `pull-projects`, `launch`, `agent-brave`, `follow-mini-player`
  for Niri, and `windows-vm`, which `windows-vm.nix` builds for NixOS and Ubuntu.
- `justfile`: the local gates; its longer recipes run scripts in `scripts/`.

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
