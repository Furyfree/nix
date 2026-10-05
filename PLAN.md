# Nix setup plan

Use this repository for NixOS systems and shared user configuration. Keep native
Windows and macOS setup in their own repositories. This is the target design;
implementation requires approval for each batch.

## Ownership

| Environment or repository | Responsibility |
| --- | --- |
| NixOS desktop and laptop | System packages, boot, disks, drivers, networking, services and sessions |
| Integrated Home Manager | Linux user configuration, selected user packages and user services |
| NixOS WSL | Minimal Linux environment, integrated Home Manager and editor server support |
| `win-setup` | Native Windows apps, system settings, BitLocker, WSL installation and native app setup |
| Swift `mac-setup` | Native macOS apps and system settings |
| Standalone Home Manager on macOS | Selected dotfiles and user packages through the existing Nix installation |
| Project flakes | Each project's development tools, including homelab |
| `wow-ui` | Cross-platform WoW settings, keybindings and addon-list handling; WowUp installs addons |
| `ai-workflow` | Agent instructions and skills |

Give each package, service and configuration destination one owner. Keep accounts,
private keys, authentication state, caches, history and downloaded app data local.
Use 1Password and native application storage for credentials.

## Repository layout

Keep the existing `hosts/` and `profiles/` structure. Add files when their
configuration is needed; the tree below shows the intended placement.

```text
flake.nix
flake.lock
PLAN.md
README.md
INSTALLATION.md
MIGRATION.md
hosts/
  nixos-test/
    configuration.nix
    hardware-configuration.nix
  desktop/
    configuration.nix
    hardware-configuration.nix
  laptop/
    configuration.nix
    hardware-configuration.nix
  wsl/
    configuration.nix
home/
  nixos-test.nix
  desktop.nix
  laptop.nix
  wsl.nix
  macos.nix
profiles/
  nixos/
    common.nix
    hyprland-noctalia.nix
    gaming.nix
    virtualization.nix
  home/
    common.nix
    linux.nix
    macos.nix
    shell.nix
    git.nix
    zed.nix
    vscodium.nix
    nvim.nix
    hyprland-noctalia.nix
    windows-dotfiles.nix
configs/
  shell/
  zed/
  vscodium/
  nvim/
  hypr/
  windows/
```

- `flake.nix`: inputs and explicit NixOS and Home Manager outputs.
- `hosts/`: machine identity, hardware and selected system profiles.
- `home/`: Home Manager entry points selecting configuration for each machine.
- `profiles/nixos/`: shared system configuration and optional features.
- `profiles/home/`: shared user configuration and application-specific modules.
- `configs/`: native application files, shared where their contents match.

Use explicit imports. Keep common profiles small enough for WSL and macOS where
applicable. Select desktop and gaming features in the hosts that need them.
Keep hardware settings and disk UUIDs with their machine.

Add `pkgs/` for a concrete custom package. Add `modules/` when a reusable custom
option is needed. Start with ordinary Nix modules and upstream options.

`README.md` holds usage, `PLAN.md` holds the target design, and `INSTALLATION.md`
holds installation instructions. Keep migration work in `MIGRATION.md`.

## Flake outputs and inputs

Expose `nixosConfigurations.nixos-test`, then add `desktop`, `laptop` and `wsl`
as those hosts become usable. Build their Home Manager configurations through
the NixOS module.

Expose a standalone `homeConfigurations."<mac-user>@<mac-host>"` for macOS.
Set its actual architecture, username and home directory before enabling it.
Use Home Manager with the Nix installation already needed for project flakes.
Swift `mac-setup` retains ownership of the rest of the Mac.

Keep the existing `nixos-unstable` and matching Home Manager inputs pinned through
`flake.lock`. Add NixOS-WSL when implementing the WSL host. Add other inputs for
specific requirements after approval. Review lock updates, build, then activate.
Keep state-version settings at their initial compatibility baselines.

## Packages and configuration

Use Nixpkgs and upstream modules for Linux packages and services where suitable.
Preserve required patches and build features from COPR when an upstream package
cannot meet the requirement, including the librepods audio fix and Voxtype
acceleration. Keep related Hyprland plugin and compositor versions compatible.

Choose Nix or Mise as the owner of each tool. Keep project-specific tools in
project flakes or existing project tooling. Native setup tools retain ownership
of native Windows and macOS application installation and updates.

Keep Lua, JSON and TOML configuration in native files where practical. Use Home
Manager checkout links for files intended for direct editing, with absolute
checkout paths supplied per machine. Generate configuration for real platform
differences. Keep mutable local preferences separate or preserve the selected
values during merges, including Zed's local model and agent settings.

Nix generations restore packages and generated configuration. Use Git to restore
editable checkout contents and separate backups for mutable application data.
Root snapshots do not cover sibling home subvolumes or Windows files.

## WSL and Windows editors

Use the maintained NixOS-WSL project. Include the Linux user, shell, Git, basic
tools, Home Manager and the editor server support needed by actual projects.
Select desktop services and physical disk configuration only on Linux hosts
that use them.

Recommend native Windows Zed and VSCodium, installed by `win-setup`, connected
to projects inside NixOS WSL. Use Zed's built-in WSL connection and VSCodium's
Open Remote - WSL extension. Configure NixOS compatibility for their Linux
servers and verify client/server versions. Linux GUI editors through WSLg remain
an option if the native workflow proves unsuitable.

The editor UI still uses Windows settings. Home Manager in WSL can supply
selected Windows dotfiles through an explicit Windows deployment hook:

- PowerShell and Windows Terminal preferences.
- Zed and VSCodium settings and keybindings.
- Git, GitHub CLI, Starship and Fastfetch configuration.
- Wallpapers.

Use actual files at Windows destinations. Obtain the intended Windows user's
real folders from `win-setup`; do not assume matching Linux and Windows usernames.
Run user-file deployment as that user, separately from elevated system setup.
Preview changes, back up existing files, preserve files on failure and report
conflicts. Repeated application should leave unchanged files alone.

Preserve Terminal's existing profiles and Zed's selected local settings. Keep
native VSCodium extension installation and wallpaper activation in `win-setup`.
Windows Neovim, 1Password SSH and Topgrade configuration remain deferred.

Keep the deployment hook limited to the selected destinations and required
merges. Windows copies and mutable merges need their own backup and restoration
behaviour; a Nix rollback does not undo those writes.

## Verification and remaining choices

Check Nix syntax and evaluate configuration before building. Test changes on
`nixos-test` before relying on them on the desktop or laptop. Use isolated checks
for settings merges, preservation on failure and repeated application. Verify
editor connections on Windows and standalone Home Manager on the actual Mac.

Confirm the Mac's architecture, username, hostname and Nix installation details.
Approve physical disk layout, bootloader and Secure Boot choices before changing
physical machines. Confirm the CLI editor and optional Windows VM requirements
when implementing those features.

## References

- [Mitchell's machine and user separation](https://github.com/mitchellh/nixos-config/blob/main/lib/mksystem.nix)
- [Misterio's NixOS and standalone Home Manager outputs](https://github.com/Misterio77/nix-starter-configs/blob/main/standard/flake.nix)
- [EmergentMind's common and optional configuration](https://github.com/EmergentMind/nix-config#structure-quick-reference)
- [fufexan's system, module and package separation](https://github.com/fufexan/dotfiles/blob/main/flake.nix)
- [NixOS-WSL](https://github.com/nix-community/NixOS-WSL)
- [Zed remote development](https://zed.dev/docs/remote-development)
- [VSCodium remote extension alternatives](https://github.com/VSCodium/vscodium/blob/master/docs/extensions-compatibility.md#remote-development)
