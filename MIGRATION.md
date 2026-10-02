# Nix migration plan

## Target

- Linux: NixOS with integrated Home Manager.
- macOS: Nix, standalone Home Manager, and a separate native installer. Consider nix-darwin later.
- Windows: a separate native installer for used apps; drop the development environment.
- Keep Fedora, Nimbus, and Chezmoi usable until the replacements work.
- Recommend pinned `nixos-unstable` with matching Home Manager. Lock Nixpkgs to a Git commit through `flake.lock`; review package changes before updating it.

## Ownership and profiles

| Owner | Responsibility |
| --- | --- |
| NixOS | Boot, disks, drivers, networking, system services, device permissions |
| Home Manager | User packages, config links, generated settings, user services |
| Mise | Language runtimes and development tools; install Mise itself through Nix |
| Flatpak | Selected Linux GUI apps |
| Native installers | macOS/Windows apps and justified Linux exceptions |
| 1Password/application storage | Private keys, credentials, accounts |

Give each package, service, and config destination one owner.

| Host | Profiles and differences |
| --- | --- |
| Desktop | Common, development, Hyprland/Noctalia, gaming, virtualization; NVIDIA/Intel |
| Laptop | Common, development, Hyprland/Noctalia, laptop gaming, virtualization; AMD, power, Wi-Fi |
| VM | Common, development, Hyprland/Noctalia; virtual hardware |
| macOS | Shared common/development selections plus native apps |

Keep the Windows VM profile optional. Separate hardware settings from reusable profiles.

## Migration scope

- Inventory used configs and packages from Nimbus, Chezmoi, and the live machines. Review Nimbus v2 docs and GitHub issues for requirements; defer new features.
- Carry over shell/Ghostty, Git/SSH, the chosen CLI editor, used Zed/VSCodium settings, Mise, Hyprland/UWSM/Noctalia, appearance, and used utility configs/services.
- Preserve development, desktop apps, gaming, virtualization, printing, audio, Bluetooth, Tailscale, and DTU networking where used.
- Keep caches, generated themes, plugin downloads, history, databases, and authentication files outside the repo. Preserve their data through backups.
- Replace Fedora provisioning with NixOS modules. Retain Fedora-only tooling only for ongoing Fedora projects.
- Preserve the LibrePods fork/patch and CLI integration, Voxtype acceleration, and matching Hyprland plugins. Audit remaining vendor apps before choosing packaging.
- Test Mise runtimes and downloaded Linux binaries on NixOS before assuming compatibility.

## Packages and updates

- Use Nixpkgs for Linux applications and system tools where suitable, including Zed and Mise. Their Nixpkgs packages disable Zed's automatic updater and `mise self-update`.
- Update `flake.lock`, build, activate, then restart affected apps. Nixpkgs must contain the newer release first. The lock pins a Git revision and its package versions, not a range such as Hyprland `0.56.x`; add separate package pins only when needed.
- Keep `mise upgrade` for Mise-managed runtimes and tools. Their versions and updates remain outside the Nixpkgs lock.
- Enable Flatpak through NixOS. Select a community module such as `nix-flatpak` to declare the app list. Flatpak apps live outside the Nix store and need their own update policy; `flake.lock` does not pin them. Nix rollback does not restore their previous versions without separate app pins, and does not restore their data.
- For packaging gaps, create a small Nix package with pinned sources or official vendor binaries, hashes, and required patches/wrappers. A patched source package requires a build. Using a vendor binary still allows Nix to own updates.
- Retain Linux vendor installers only for concrete packaging, compatibility, or release-timing needs. Test installer effects and downloaded binaries; use `nix-ld` and required libraries where appropriate. Vendor-managed versions remain outside Nix locking and rollback.
- Keep native GUI app updates on macOS/Windows. Adapt Topgrade and other update commands to the selected owners; avoid competing self-updaters for Nix-managed apps.

## Config workflow

Keep native config files under `configs/`. Use Home Manager's `mkOutOfStoreSymlink` with absolute string paths into the checkout:

```text
~/.config/nvim/init.lua → ~/Projects/nix/configs/nvim/init.lua
```

Edit the application path, reload if needed, then commit the repo change. Package, service, and link changes require a build and activation. Pull on other computers and activate changed declarations there.

Use shared files where possible; select platform-specific files or generate settings for genuine Linux/macOS differences. Apps can use these configs without installation through Nix.

Use Git to restore linked file contents and Nix generations to restore packages/generated configuration. Keep personal-data backups separate.

## 1Password

Enable the NixOS GUI/CLI modules and desktop authentication integration. Configure SSH agent paths and Git SSH signing per platform; use native 1Password on macOS.

Keep private keys in 1Password. Complete sign-in and agent activation interactively. Fetch secrets at runtime or keep private files outside the Nix store; remove secret-rendering Chezmoi templates from the migrated configuration.

## Implementation order

1. Confirm inventory, ownership, package gaps, and profile selections.
2. Create the flake and VM host with integrated Home Manager and a minimal shell. Verify boot, networking, and login.
3. Migrate CLI configs and development tools. Verify direct edits, SSH authentication, signed commits, and project builds.
4. Add Hyprland/Noctalia and custom packages. Verify portals, screen sharing, audio, Bluetooth, browser integration, and services.
5. Back up and test restoration; preserve a Fedora recovery route and the separate Windows disk. Approve partitioning, bootloader, and Secure Boot choices before installation.
6. Migrate the desktop; test NVIDIA, displays, peripherals, gaming, Docker, and virtualization on real hardware.
7. Migrate the laptop; test Wi-Fi, suspend, battery behaviour, and peripherals.
8. Build/test the macOS bootstrap and shared Home Manager setup on the Mac. Retain a minimal Windows installer.
9. Adapt update commands, remove overlapping ownership, then archive old repos only after a successful cutover and explicit approval.
10. Build a custom NixOS installer ISO from the tested configs, following the [bootable ISO tutorial](https://nix.dev/tutorials/nixos/building-bootable-iso-image.html). Include SSH access, installation tools, and an installation workflow for the agreed LUKS2/Btrfs layout with manual passphrase entry. Test USB boot and a full installation on a disposable machine.

Review encryption, firewall, and service restrictions before cutover; account for losing Fedora's SELinux baseline. Build before activation and test rollback. Keep state-version settings at their initial compatibility baselines unless a documented migration requires changing them.

## Remaining decisions

- CLI editor: recommend the existing minimal Neovim setup; confirm before migration.
- Mac architecture, username, and Nix installer.
- Physical disk layout, bootloader, and Secure Boot.
- Whether to keep the Windows VM profile.
- Repo layout: propose `hosts/`, `profiles/{nixos,home}/`, `modules/{nixos,home}/`, `configs/`, and `packages/`; create only needed directories.
