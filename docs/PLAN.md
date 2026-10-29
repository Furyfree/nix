# Plan

Open work only; finished work lives in Git.

## Move onto NixOS

1. Install the laptop, then the desktop, with [INSTALLATION.md](../INSTALLATION.md)
   and run its checks.
2. Add the OpenRouter key to ai-usagebar's config when wanted.
3. Then retire Fedora, Nimbus, Chezmoi, COPR and fedora-iso, and
   `docs/POSTINSTALL.md` in the docs repository.
4. Watch laptop Wi-Fi. Under wpa_supplicant the MT7925 timed out WPA3's
   6 GHz handshake (reason 15), which NetworkManager read as a wrong password;
   that is likely what Fedora's boot retry papered over. Every host now uses
   iwd. Confirm reconnects and resume without password prompts, and eduroam at
   DTU; revert the backend in `components/networking.nix` if eduroam fails.
5. Retest two Noctalia clipboard bugs from Fedora with sample text: a
   1Password field pasted into Wi-Fi fields and launcher search must paste the
   current value and stay out of history (noctalia#4457), and text copied in
   Ghostty must paste after Ghostty closes without picking it from history
   (noctalia#3793).
6. Remove the temporary SSH server from `hosts/laptop/configuration.nix` once
   the laptop works.

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

## Later platforms

- macOS: standalone Home Manager links the shared configs (`home/darwin.nix`,
  flake outputs `macos-personal` and `macos-work` for Apple silicon); Swift
  mac-setup installs the apps and tools INSTALLATION.md lists and owns system
  settings. On macOS 27.0.1 with Nix 2.35.4, `macos-personal` builds and
  activates; commits sign and SSH reaches GitHub through 1Password, Homebrew's
  fastfetch runs the shared config, and `nix-workstation` switch, info and
  rollback work. Still open:
  - `macos-work`: bring the work Mac's local `pull-projects` status table into
    the tracked script, keep its private SSH hosts in `~/.ssh/local.conf`,
    then build, activate and check its routing with `ssh -G`.
  - An `aarch64-darwin` dev shell, and `just eval-macos`, which evaluates and
    builds both Mac activation packages from a temporary checkout with a
    placeholder user. `nix flake check` skips `homeConfigurations`, so
    `nupdate` on the Mac must build the package to check it.
  - `home/darwin.nix`: Toolbox autostart off in
    `~/Library/Application Support/JetBrains/Toolbox/.settings.json`;
    VSCodium's settings only where VSCodium is installed; links for OmniWM,
    Tinycast and Rex once their configurations are committed. Work
    differences beyond the SSH keys start empty; the work Git identity stays
    local.
  - zsh: load Nix's daemon profile when `nix` is missing from `PATH`, since a
    macOS update can reset `/etc/zshrc`; `HOMEBREW_NO_AUTO_UPDATE=1` outside
    the Homebrew owner's account; `compinit -u` only when `compaudit` lists
    nothing outside `/opt/homebrew`. Git: `safe.directory = /opt/homebrew`,
    so accounts other than the Homebrew owner can run `brew`.
  - `codium-extensions`: macOS `xargs` has no `-a`.
  - `nix-workstation`: `nupdate`, as the Homebrew owner, quits OmniWM and runs
    `brew upgrade` plus `--greedy` for Office; `fup` runs
    `softwareupdate --list` instead of stopping; test `nclean`.
  - INSTALLATION.md: mac-setup installs Nix with flakes; Home Manager's own
    dependencies, such as Yq, still come from Nix; and the tool list matches
    mac-setup's `common.Brewfile`: `tree-sitter-cli`, `unar` instead of unrar,
    and no `nixd` or `nh`.
  - Move cross-platform tools out of `mise/conf.d/linux-tools.toml`, and
    `actionlint` to its maintained fork `jactionlint`.
  - fastfetch: drop the NixOS logo and the OS age and desktop lines on macOS.
  - Check Ghostty's shared GTK settings and the editors' shortcuts on the Mac
    keyboard.
- WSL: NixOS-WSL with integrated Home Manager and selected Linux tools.
  win-setup owns Windows setup and apps; test editor server compatibility and
  keep Terminal profiles and Zed local values in backed-up Windows copies.
