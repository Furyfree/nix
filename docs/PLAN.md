# Plan

Open work only; finished work lives in Git.

## Untested recovery

- Snapshot restore. Test file recovery by changing a file in `/etc` and in `~`,
  then copying the `/etc` one back from `/.snapshots/<n>/snapshot/`; only
  `/etc` is in root snapshots. Whole-root recovery: boot the ISO, keep the
  current `root` subvolume, create a writable copy of the chosen snapshot
  named `root`, update the boot menu from it and reboot. Never format.
- USB recovery. The standard ISO needs Secure Boot off; decide whether that is
  enough or a signed recovery image is needed.

## Windows and WSL

Both move here from win-setup; only its lists and checks come over.

- Windows: one Python script, `windows/setup.py`, reads `windows/setup.toml`
  (apps and registry values) and uses only the standard library, winget and
  yq. PowerShell only for the bootstrap and short cmdlet calls that get their
  data through environment variables.
- WSL: NixOS-WSL as another NixOS host. Development happens there.

### 1. Windows (here, then a VM, then the desktop)

- Rules for AGENTS.md when it lands: never uninstall apps; save old registry
  values before the first apply; Secure Boot, TPM, Defender, Firewall, UAC and
  Windows Update stay on; BitLocker keys never appear in output or logs.
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

### 2. WSL

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
- Afterwards, remove Fedora by hand with `wsl --unregister`, which deletes
  its data.

### 3. Windows development tools (last)

- Mise and a short tool list on Windows itself, and the agent settings
  merges. Decide the list then.

### 4. Retire win-setup

- Archive it with a README pointing here once phases 1 and 2 run on real
  machines.

### Fallbacks

- 1Password misbehaves in WSL: relay its agent with npiperelay and socat.
- NixOS-WSL disappoints: Ubuntu with standalone Home Manager reuses `home/`.
