# Nix setup plan

Finish boot, storage and the installer ISO before migrating userland. Desktop
and laptop share workstation defaults, with hardware and preferences per host.
Use `nixos-test` first; keep Fedora, Nimbus and Chezmoi until replacements work.

## Shared setup

- `system.nix`: shared Linux packages, services and component imports.
- `home.nix`: shared Home Manager config mappings and user services.
- `components/`: related packages and system features; use explicit imports.
- `hosts/`: machine settings, generated hardware, disks, GPU and monitor choices.
- `configs/`: native app files linked into the checkout with Home Manager's
  `mkOutOfStoreSymlink` and each machine's absolute checkout path.
- `flake.nix` and `flake.lock`: host outputs and pinned inputs. Keep placeholder
  files outside active imports and enable hosts as their configurations work.

## Boot and storage

Use UEFI, a 4 GiB FAT32 EFI partition at `/boot`, and LUKS2-encrypted Btrfs.
Keep the test machine's existing 1 GiB EFI partition until reinstalling it.
Unlock with a passphrase; the test machine has no TPM. Keep `/nix` inside root,
the existing sibling subvolumes and Snapper policy. Defer Windows VM storage
and whole-root snapshot restoration; root snapshots exclude `/boot` and `/home`.

| Host | Hardware | RAM | SSD | Swap |
| --- | --- | --- | --- | --- |
| Desktop | NVIDIA/Intel | 32 GiB | 2 TB | 48 GiB |
| Laptop | AMD | 64 GiB | 1 TB | 96 GiB |

1. Replace systemd-boot with upstream Limine, removing duplicate kernel settings.
   Enable Plymouth and Danish keyboard input; keep US as a commented alternative.
2. Create a Btrfs swap file inside LUKS at `/var/swap/swapfile`. Check test-host
   RAM first; set the resume device and file offset, then test hibernation.
3. Arrange the menu: current generation, other operating systems when present,
   older generations in a submenu, then firmware access. Reuse upstream support.
4. Enable upstream Limine signing and config/kernel/initrd verification. Enrol
   keys with separate approval; keep private keys outside the repo and ISO.
5. Check kernel lockdown and Secure Boot/hibernation compatibility before relying
   on both. Repeat cold boot, reboot, unlock, rollback and resume on each host.

Check EFI capacity and generation retention, early storage/display drivers and
keyboard input. Keep a tested recovery USB; defer boot appearance work.

## Installer ISO

Use the [upstream minimal installer](https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix)
and native NixOS image builders; `nixos-generators` is deprecated. Keep the live
installer separate from workstation settings; it need not boot through Limine.

- Build one ISO with a host menu for `nixos-test`, desktop and laptop.
- Use Python and Questionary with native NixOS tools, without Disko or another
  installer framework.
- Ask for the disk and mode: erase the whole disk or use unallocated space.
  Preserve mode must stop if space is insufficient; do not shrink or format
  existing partitions. Review disk/partition changes and confirm before writing.
- Prompt for the encryption passphrase. Require internet for installation; include
  offline recovery tools and networking/Wi-Fi setup. Use the local console;
  keep the image's SSH server disabled.
- Bundle the repo and lock file. Generate target hardware settings and UUIDs;
  install an editable checkout rather than reuse the test machine's identifiers.
- Keep recovery separate from installation; recovery must not trigger formatting.
- Test USB/UEFI boot and both install modes in disposable VMs. Check existing
  partitions, data and boot files, insufficient space, interrupted/repeated runs
  and boot repair before touching physical disks.

Review `scripts/install.py` and `tests/test_installer.py` for a split by job:

- Planning and disk discovery.
- Wizard prompts and review.
- Storage preparation, safety checks and cleanup.
- Configuration cloning, generation and evaluation.
- Native installation and verification.

Keep `scripts/install.py` as a thin launcher. Split tests along the same
boundaries and update ISO packaging to include all modules. Preserve behavior,
disk guards, read-only previews and native password entry; add no framework or
dependencies. Propose the exact files and wait for approval before code changes.
Verify with the existing tests, type checks, flake evaluation and packaged wizard.

Before the full installation test:

1. Commit and push the installer changes to GitHub's `main`.
2. Make the repository public.
3. Build the ISO with `just build-iso`.
4. Test `nixos-test` erase installation and boot in a disposable UEFI VM.
   Attach throwaway virtual disks, not host disks.

ISO builds work while the repo is private. Installation needs public access
because the installer clones GitHub's latest `main`, keeping its lock file.

## Userland after boot

1. Configure Hyprland/UWSM and Noctalia: auto-login as the chosen user, greeter after logout,
   and session locking before suspend or hibernation.
2. Migrate shell, Git/SSH, CLI tools, Mise, editors and apps one tool at a time.
   Confirm the login shell and CLI editor before migration. Build and check each
   batch on `nixos-test`; preserve existing files on config conflicts.
3. Add appearance, audio, Bluetooth, printing, networking, gaming and virtualization
   where used. Preserve LibrePods patches/CLI integration, Voxtype acceleration
   and compatible Hyprland plugins. Test hardware features on the actual hosts.

Use Nixpkgs and upstream modules first, with one installer/updater per package.
NixOS owns Linux system features/apps; Home Manager owns user configuration;
Mise owns its runtimes/tools. Keep Flatpak and justified native installers on
separate update policies. Test downloaded binaries; choose wrappers when needed.
Keep state versions at their original baselines. Review lock updates, build,
then activate; Nix rollback does not restore external packages or mutable data.

Add `nbuild` (build), `nswitch` (activate with Snapper pre/post snapshots),
`nupdate` (update lock only), `nsearch` and `nshell`. Build/activation shortcuts
must target this repo's explicit flake path and host from any working directory.
Move dotfiles' Pi-package hook into Home Manager after Mise installs Pi; keep
`npm:pi-terminal-math` unpinned and Pi settings/local packages writable.

Keep secrets, credentials, history, caches and downloaded plugins outside the
repo/Nix store. Use 1Password for keys/authentication, with SSH agent and Git
signing per platform. Preserve local Zed model/agent settings and selected
Obsidian preferences/plugin settings; the vault keeps content, plugins and lists.
Leave vis, Niri, DMS and wallpapers out.
ai-workflow owns agent instructions/skills; wow-ui remains independent.

## Later platforms and open choices

- macOS: standalone Home Manager for shared configs; Swift mac-setup owns native
  apps/settings. Confirm architecture, user paths and installer before enabling.
- WSL: NixOS-WSL with integrated Home Manager and selected Linux tools. win-setup
  owns Windows setup/apps; test native editor server compatibility and preserve
  Terminal profiles/Zed local values in backed-up Windows config copies/merges.
- Decide EFI handling in preserve mode and recovery with Secure Boot enabled:
  standard ISOs require disabling it, or we need a trusted signed recovery image.
- Confirm the CLI editor/login shell, optional Windows VM, and Flatpak module.
- Approve each implementation batch. Approve physical disk, bootloader activation
  and firmware/key changes separately; retire old provisioning only after tests.
