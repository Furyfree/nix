# Nix setup plan

Build one shared NixOS workstation setup for user's desktop and laptop. Use the
same default packages, services, configs and preferences, with any deliberate
differences in each host. Keep macOS and WSL as planned extensions with
comment-only placeholders for now.

## Structure

```text
flake.nix
flake.lock
system.nix
home.nix
hosts/
  nixos-test/
    configuration.nix
    hardware-configuration.nix
    home.nix
  desktop/
    configuration.nix
    hardware-configuration.nix
    home.nix
  laptop/
    configuration.nix
    hardware-configuration.nix
    home.nix
  wsl/
    configuration.nix
    home.nix
  macos/
    home.nix
components/
  cli.nix
  development.nix
  editors.nix
  hyprland-noctalia.nix
  gaming.nix
  virtualization.nix
configs/
  zed/
  ghostty/
  obsidian/
  ...
```

| Part | Responsibility |
| --- | --- |
| `configs/` | Native application files, added once and shared where suitable |
| `components/` | Related Linux packages and required system features |
| `system.nix` | Select components and define shared Linux system settings |
| `home.nix` | Select shared Linux configs and map each source file to its destination through Home Manager |
| `hosts/<machine>/` | Select shared defaults or components, define hardware and add machine-specific packages or preferences |
| `flake.nix` | Pin inputs and expose configurations for the selected hosts |

Use ordinary Nix modules and explicit imports. Reuse upstream NixOS and Home
Manager options. Add a custom package only for a concrete packaging requirement.

Only `nixos-test` is active. Keep the shared modules and config directories
empty until migrating each tool. Desktop, laptop, macOS and WSL remain
placeholders. Migrate, build and check one tool before starting the next.

## Mirrored Linux workstations

Both desktop and laptop will import root `system.nix` and `home.nix` for their
shared defaults. Add shared software to `system.nix` and config mappings to
`home.nix` once.

Keep hostname and extra packages or services in each host's `configuration.nix`.
Keep generated hardware, disks and encryption in `hardware-configuration.nix`.
Use the host's `home.nix` for different preferences or config mappings, such as
monitor layouts or Voxtype's model. For example, add Gimp to the desktop host
if only the desktop needs it; leave shared package groups in `components/`.
Both hosts will inherit the shared setup through ordinary Nix imports.

`system.nix` will select CLI, development, editor, Hyprland/Noctalia, gaming and
virtualization components. A component can contain packages, related system
settings or both. Hosts can import extra components directly. Keep user config
destinations in `home.nix`, with machine-specific differences in each host.

Use `nixos-test` to try the shared setup before relying on it on either
workstation. Keep its working bootstrap until the shared files contain usable
Nix modules. Comment-only placeholders must remain outside active imports.

## Config selection and destinations

Keep application files in `configs/`. They contain the application's settings.
`home.nix` selects those files and declares their destinations:

```text
configs/zed/settings.json -> ~/.config/zed/settings.json
configs/zed/keymap.json   -> ~/.config/zed/keymap.json
configs/ghostty/config   -> ~/.config/ghostty/config
```

Use Home Manager checkout links for files intended for direct editing. Supply
the absolute checkout path per machine. Generate files for real platform
differences, and preserve selected local values when a config needs merging,
including Zed's model and agent preferences.

Include Obsidian's per-machine preferences and selected plugin settings. The
vault repository retains its content, plugins and plugin lists. Leave vis,
Flatpak configuration, wallpapers, Niri and DMS out of the current scaffold.

Keep credentials, private keys, accounts, history, caches, downloads and runtime
databases outside the repo. ai-workflow owns agent instructions and skills;
this repo owns selected agent application settings.

## Package ownership and updates

NixOS owns Linux system packages, drivers, networking, services and sessions.
Integrated Home Manager owns user configuration and selected user services.
Choose one installer and updater for each package; avoid overlap between Nix
and Mise. Each project's flake retains its project-specific development tools.

Use Nixpkgs packages and upstream modules first. Preserve required COPR patches
or build features when an upstream package cannot meet the actual requirement.
Keep Hyprland plugins compatible with the selected compositor version.

Keep the existing nixos-unstable and matching Home Manager inputs pinned through
`flake.lock`. Review lock updates, build, then activate. Keep state-version
settings at their initial compatibility baselines.

Nix generations restore declarative packages and configuration. Use Git for
editable config contents and separate backups for mutable data. Root snapshots
do not cover sibling home subvolumes or Windows files.

## Future macOS and WSL

Keep their host files as placeholders. Add their flake outputs and required
inputs when implementing those platforms. Select suitable files from `configs/`
in each host; WSL can also select the Linux components it needs. Root
`system.nix` and `home.nix` will contain the shared Linux workstation defaults.

For macOS, use standalone Home Manager with the Nix installation already
needed for project flakes. `hosts/macos/home.nix` selects shared configs and
maps macOS destinations. Swift mac-setup owns native apps and system settings.
Confirm the Mac's architecture and paths before enabling its output.

For WSL, use NixOS-WSL and integrated Home Manager with a minimal Linux tool
selection. win-setup owns Windows setup and installation of the WSL distribution.
Native Windows Zed and VSCodium can connect to Linux projects; configure and
test their server compatibility when implementing that workflow.

Plan selected Windows config copies and merges in `hosts/wsl/home.nix`.
Use the intended Windows user's actual folders, backups and visible conflict
handling. Preserve Terminal profiles and selected Zed local settings.
win-setup retains native extension installation and system changes. Windows
file writes need their own recovery; Nix rollback does not undo those copies.

wow-ui remains independent for cross-platform WoW settings, keybindings and
addon-list handling. WowUp installs addons.

## Verification and implementation boundaries

Approve each implementation batch. Check placeholder contents and parse active
Nix files after scaffold changes. Evaluate and build the test host before
activation. Test config merges for preservation, failure handling and repeated
application when implementing them.

Test desktop and laptop hardware behaviour on their actual machines. Approve
physical disk, bootloader and Secure Boot changes separately. Leave macOS and
WSL integration checks until those platforms enter implementation.

README.md holds usage, PLAN.md holds the target design, and INSTALLATION.md
holds installation instructions. Keep migration work in MIGRATION.md.

## References

- [Mitchell's machine and user separation](https://github.com/mitchellh/nixos-config/blob/main/lib/mksystem.nix)
- [Misterio's NixOS and standalone Home Manager outputs](https://github.com/Misterio77/nix-starter-configs/blob/main/standard/flake.nix)
- [EmergentMind's shared and optional configuration](https://github.com/EmergentMind/nix-config#structure-quick-reference)
- [fufexan's system and package organisation](https://github.com/fufexan/dotfiles/blob/main/flake.nix)
- [NixOS-WSL](https://github.com/nix-community/NixOS-WSL)
- [Zed remote development](https://zed.dev/docs/remote-development)
- [VSCodium remote extension alternatives](https://github.com/VSCodium/vscodium/blob/master/docs/extensions-compatibility.md#remote-development)
