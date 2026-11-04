# Plan

Open work only; finished work lives in Git.

## NixOS follow-up

1. Add the OpenRouter key to ai-usagebar's config when wanted.
2. Retest two Noctalia clipboard bugs from Fedora with sample text. A
   1Password field pasted into Wi-Fi fields and launcher search must paste the
   current value and stay out of history (noctalia#4457). It is fixed upstream
   but not released; retest once a release with the fix reaches nixpkgs
   (5.4.0 is pinned now). Text copied in Ghostty must paste after Ghostty
   closes without picking it from history (noctalia#3793).

## Untested recovery

- Snapshot restore. Test file recovery by changing a file in `/etc` and in `~`,
  then copying the `/etc` one back from `/.snapshots/<n>/snapshot/`; only
  `/etc` is in root snapshots. Whole-root recovery: boot the ISO, keep the
  current `root` subvolume, create a writable copy of the chosen snapshot
  named `root`, update the boot menu from it and reboot. Never format.
- USB recovery. The standard ISO needs Secure Boot off; decide whether that is
  enough or a signed recovery image is needed.
- Test installer changes in disposable UEFI VMs with throwaway disks, never on
  host disks.

## One repo for every machine

This repo sets up NixOS, the Macs, Windows and WSL. mac-setup and win-setup
are archived once their machines run from here; only their lists and checks
move over.

- Macs: nix-darwin with Home Manager. Homebrew installs apps, fonts and
  command-line tools; Nix installs only nixd and nh, which Homebrew lacks.
  A tool added to `components/shell.nix` goes into the shared Homebrew list.
- Windows: one Python script, `windows/setup.py`, reads `windows/setup.toml`
  (apps and registry values) and uses only the standard library, winget and
  yq. PowerShell only for the bootstrap and short cmdlet calls that get their
  data through environment variables.
- WSL: NixOS-WSL as another NixOS host. Development happens there.
- Mise: developer tools on every machine. Runtimes on Linux and the
  personal Mac, agent CLIs on Linux and the work Mac (`configs/mise/conf.d/`).
- Work Mac: the shared setup and work SSH keys only. Work apps, VPNs and IT
  details never enter this repo.
- Personal Mac: macOS settings apply to my account only.

Rules for AGENTS.md as each part lands: never remove apps (no Homebrew
cleanup, no winget uninstall); save old settings before the first apply;
the work Mac never gets what IT manages; FileVault, SIP, Gatekeeper,
Secure Boot, TPM, Defender, Firewall, UAC and Windows Update stay on;
BitLocker keys never appear in output or logs.

### 1. Macs (VM, then each Mac)

- Run `darwin/bootstrap.sh` on a throwaway macOS 27 VM, log out, then
  `nswitch` again: it must change nothing. Check the settings with
  mac-setup's `TASKS.md`, and move the checks still open into this plan.
- Then the personal Mac, as `INSTALLATION.md` describes; the work Mac once IT
  allows Nix and Homebrew.
- Done when: both Macs switch and the checks pass.

### 2. Windows (here, then a VM, then the desktop)

- `setup.toml`: apps from `Packages.cs` without Chezmoi, fnm, Mise, CMake,
  Ninja and the agent CLIs, plus delta; registry values from `Settings.cs`.
- `setup.py status` only reads. `setup.py apply`: save old registry values
  once; `winget install --no-upgrade`; registry; night light; wallpaper from
  the `~/Projects/wallpapers` clone once it exists, as on Linux; power;
  links and merges; BitLocker with today's key-file rules; restart Explorer.
- Links: Git, Starship, Neovim, VSCodium, the PowerShell profile (with the
  `nswitch` alias), a Windows SSH config (1Password's pipe, not the socket
  path) and 1Password's `agent.toml`. Merges through yq: Windows Terminal
  and Zed. `setup.py` writes `~/.config/git/windows` with 1Password's signer
  path; `configs/git/config` includes it.
- Port the PowerShell profile and Terminal settings from the archived
  dotfiles repo into `configs/windows/`. Keep script execution allowed for
  the profile.
- `windows/bootstrap.ps1`: install Git and uv, clone, run `setup.py apply`
  elevated.
- `tests/test_windows_setup.py` with fake commands runs in `just check`.
- Done when: on a Windows 11 VM a second `apply` changes nothing and
  `status` is clean; then the desktop.

### 3. WSL

- Flake: NixOS-WSL input; `nixosConfigurations.wsl` from
  `hosts/wsl/local/user.nix` (Linux and Windows user). It imports the shell,
  CLI and development components, not `system.nix`.
- `home/wsl.nix`: `common.nix`, with Zed's package off. SSH and Git signing
  go through Windows' `ssh.exe` and `op-ssh-sign-wsl`, so WSL gets no Linux
  SSH config. `nix-workstation` skips Snapper and firmware.
- `setup.py`: `wsl --install --no-distribution`; pinned `nixos.wsl` with its
  checksum; `wsl --install --from-file`; then print: first switch from a
  temporary clone to set my user, restart the distro, clone to
  `~/Projects/nix`, `nswitch`.
- `just eval-wsl` in `just check`; build only on demand.
- Done when: `nswitch`, a signed commit, `ssh.exe -T git@github.com`, and
  VSCodium and Zed connecting all work. Then remove Fedora by hand with
  `wsl --unregister`, which deletes its data.

### 4. Windows development tools (last)

- Mise and a short tool list on Windows itself, and the agent settings
  merges. Decide the list then.

### 5. Retire the old repos

- Update `AGENTS.md`'s map and the README as each part lands.
- Archive mac-setup and win-setup with a README pointing here, after
  phases 1 to 3 run on real machines.

### Carried over from mac-setup

- T3 Code: find where it keeps its settings on the Mac; if in
  `~/.t3/userdata` as on Linux, move its three links from `home/linux.nix`
  to `home/common.nix`.

### Fallbacks

- A macOS update resets `/etc/zshrc`: run `nswitch` again.
- 1Password misbehaves in WSL: relay its agent with npiperelay and socat.
- NixOS-WSL disappoints: Ubuntu with standalone Home Manager reuses `home/`.
