# Nix setup plan

Proceed with [userland setup](#userland-after-boot). See the
[installation status](../README.md#install). Desktop and laptop share workstation
defaults, with hardware and preferences per host. Use `nixos-test` first; keep
Fedora, Nimbus and Chezmoi until replacements work.

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
Unlock with a passphrase; the test machine has no TPM. Keep `/nix` inside root,
the existing sibling subvolumes and Snapper policy; `windows-vm install`
creates a sibling `windows` subvolume for the VM. Defer whole-root snapshot
restoration; root snapshots exclude `/boot` and `/home`.

Snapshot restoration is untested; the ISO reinstall erased the first manual
install's test snapshot. Test file recovery: change a test file in `/etc` and
`~`, copy the `/etc` one back from `/.snapshots/<n>/snapshot/`, and expect only
`/etc` restored. Whole-root recovery: boot the ISO, keep the current `root`
subvolume, create a writable copy of the chosen snapshot named `root`, update
the boot menu from it, then reboot; never format.

Rollback works: `nixos-rebuild boot --rollback`, reboot, then return with
`nixos-rebuild switch --flake path:<checkout>#<host>`. It restores the system,
not mutable files. Activate with `nswitch` to take Snapper pre/post snapshots.

| Host | Hardware | RAM | SSD | Swap |
| --- | --- | --- | --- | --- |
| Desktop | NVIDIA/Intel | 32 GiB | 2 TB | 48 GiB |
| Laptop | AMD | 64 GiB | 1 TB | 96 GiB |

Keep upstream Limine's generation menu and built-in firmware setup shortcut.
Defer other-OS discovery until dual boot is needed; use upstream EFI entries
before adding automatic detection. Recheck cold boot, reboot and unlock after
bootloader changes.

USB recovery testing is deferred and does not block userland setup. Keep it
unverified until tested.

Qotom does not support Secure Boot. Defer signing and config/kernel/initrd
verification setup and testing to a machine that supports it; this does not
block Qotom work or userland migration. Use upstream Limine support, enrol keys
with separate approval and keep private keys outside the repo and ISO.

Keep the encrypted swap/resume settings. On Qotom, manual hibernation resumes
locked and Noctalia's two-hour idle hibernation triggers; an open Windows VM
window blocks suspend and hibernation. Defer compatibility checks with kernel
lockdown and Secure Boot to the desktop or laptop.

Check EFI capacity and generation retention, early storage/display drivers and
keyboard input; defer boot appearance work.

## Installer ISO

Use the [upstream minimal installer](https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix)
and native NixOS image builders; `nixos-generators` is deprecated. Keep the live
installer separate from workstation settings; it need not boot through Limine.

- Build one ISO with a host menu for `nixos-test`, desktop and laptop.
- Use Python and Questionary with native NixOS tools, without Disko or another
  installer framework.
- Ask for the machine and disk, then erase the whole disk. Dual boot uses a
  separate Windows disk, so there is no free-space mode. Review the disk and
  confirm before writing.
- Prompt for the encryption passphrase. Require internet for installation; include
  offline recovery tools and networking/Wi-Fi setup. Use the local console;
  keep the image's SSH server disabled.
- Bundle the repo and lock file. Generate target hardware settings and UUIDs;
  install an editable checkout rather than reuse the test machine's identifiers.
- Keep recovery separate from installation; recovery must not trigger formatting.
- Test future installer changes and preserve mode in disposable UEFI VMs. Check
  existing partitions, data and boot files, insufficient space,
  interrupted/repeated runs and boot repair before deploying those changes.

Build future installer changes with `just build-iso`. Use throwaway virtual
disks for VM tests, not host disks.

## Userland after boot

Migrate one batch at a time and check each on `nixos-test` before the next.
Remaining order:

1. CLI tools: git-lfs, just, lazygit, yq, file, zip/unzip/7zip/unrar,
   poppler-utils, ImageMagick, yt-dlp, typst, duf, tokei, nmap, gitleaks.
2. System services and polish: fwupd, power profiles/upower, Tailscale,
   WireGuard, OpenConnect, Nautilus/file-chooser preferences, hidden launcher
   entries and `pull-projects`.
3. Launcher and everyday apps: a `launch` script for web apps (FotMob, Google
   Maps) and later helpers such as a floating terminal; Brave, Signal, Vesktop,
   Spotify, Obsidian with vault settings, Fastmail, WoeUSB and JetBrains Toolbox
   without autostart; wallpapers in their own repo, cloned to
   `~/Pictures/Wallpapers`.
4. Devices: LibrePods as our own package with its patches, NuPhy and Wooting files.
5. Gaming: Steam, gamemode, gamescope, MangoHud, Heroic, ProtonPlus, Prism
   Launcher and WowUp, tested on the Qotom first. Proton, protontricks and
   Heroic cover Lutris, standalone Wine and umu; MangoHud settings replace
   GOverlay.
6. AI: agent CLIs and configs, ACP adapters, ai-usagebar, Pi packages and T3
   Code; then Claude Desktop, packaged from Anthropic's signed Debian package.
7. Hyprland plugins: ScrollOverview, built by Nix and loaded from `overview.lua`.
8. Printing, when a printer can test it.
9. Sign-in tools: 1Password (app, CLI, SSH agent), Git signing and `gh`. After
   signing in: `op document get 3223bqk2tzqdut7gdhiqjyqj34 --out-file
   ~/.ssh/local.conf` for the homelab hosts, `gh auth login`, the
   wallpapers repo cloned into `~/Projects` (the next rebuild links it to
   `~/Pictures/Wallpapers`), the OpenRouter key in ai-usagebar's config, and the
   Fastmail calendar through Noctalia's settings. Sign-in tests wait for this
   batch: the agent CLIs, the AI usage widget and Claude Desktop, plus
   ai-workflow's `just install` on the real hosts.
10. Real hosts, in three parts. Hosts and installer: `desktop`, `laptop` and
    `nixos-test` build from their own local data; the installer asks for the
    machine, erases only the chosen disk, and adds a Limine entry for Windows
    on another disk. Desktop: NVIDIA open modules with Intel, the boot-display
    rule, GIMP, the full gaming set and its monitors and workspaces in
    `configs/hypr/hosts/desktop.lua`. Laptop: fingerprint, brightnessctl,
    Wi-Fi retry, light gaming and its panel scale. Shared: ddcutil, firmware,
    lid-guard, DTU eduroam (`dtu-eduroam [1PASSWORD-ITEM]` writes the login)
    and Voxtype (`voxtype setup --download --model <model>` once per host).
11. Install the desktop and laptop, run their hardware tests (including
    LibrePods, since the Qotom has no Bluetooth), then retire Fedora, Nimbus,
    Chezmoi, COPR and fedora-iso.

Bring each app's Noctalia plugin, widget and keybind back in the batch that
installs the app; commented entries in `configs/` mark what waits. Noctalia
renders templates only when the palette changes, so run
`noctalia msg templates-apply` once after installing an app with a template.

Use Nixpkgs and upstream modules first, with one installer/updater per package.
NixOS owns Linux system features/apps; Home Manager owns user configuration;
Mise owns its runtimes/tools. Keep Flatpak and justified native installers on
separate update policies. Test downloaded binaries; choose wrappers when needed.
Keep state versions at their original baselines. Review lock updates, build,
then activate; Nix rollback does not restore external packages or mutable data.

Use nh with `NH_FLAKE` set to the checkout's `path:` flake: `nh os build`,
`nh search` and `nswitch` (`nh os switch` between Snapper pre/post snapshots).
Update only the lock with `nix flake update --flake "$NH_FLAKE"`.
Nix installs Mise and nix-ld; run `mise install` after a rebuild and
`mise upgrade` for tool updates. Topgrade is dropped: nh, Mise and Sheldon
update their own parts. No Flatpak while every app is in nixpkgs, including
Fedora's Pinta, Spotify and Fastmail Flatpaks.
Move dotfiles' Pi-package hook into Home Manager after Mise installs Pi; keep
`npm:pi-terminal-math` unpinned and Pi settings/local packages writable.

Keep secrets, credentials, history, caches and downloaded plugins outside the
repo/Nix store. Use 1Password for keys/authentication, with SSH agent and Git
signing per platform. Preserve local Zed model/agent settings and selected
Obsidian preferences/plugin settings; the vault keeps content, plugins and lists.
Leave vis, Niri, DMS, Bash with ble.sh, ChatGPT desktop, Zeron and agent-proxy
(with Copilot desktop) out.
ai-workflow owns agent instructions/skills; wow-ui remains independent.

## Later platforms and open choices

- macOS: standalone Home Manager for shared configs; Swift mac-setup owns native
  apps/settings. Confirm architecture, user paths and installer before enabling.
- WSL: NixOS-WSL with integrated Home Manager and selected Linux tools. win-setup
  owns Windows setup/apps; test native editor server compatibility and preserve
  Terminal profiles/Zed local values in backed-up Windows config copies/merges.
- Decide EFI handling in preserve mode and recovery with Secure Boot enabled:
  standard ISOs require disabling it, or we need a trusted signed recovery image.
- Approve each implementation batch. Approve physical disk, bootloader activation
  and firmware/key changes separately; retire old provisioning only after tests.
