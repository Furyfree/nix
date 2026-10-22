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

- macOS: standalone Home Manager for the shared configs (`home/darwin.nix`,
  flake output `homeConfigurations.macos` for Apple silicon); Swift mac-setup
  owns native apps and settings. It evaluates but has not run on a Mac yet.
  Still open: a macOS branch in `nix-workstation` (nh home, no Snapper),
  fastfetch's Lua rows (the Linux override relies on LD_LIBRARY_PATH), and
  matching mac-setup's app list to INSTALLATION.md.
- WSL: NixOS-WSL with integrated Home Manager and selected Linux tools.
  win-setup owns Windows setup and apps; test editor server compatibility and
  keep Terminal profiles and Zed local values in backed-up Windows copies.
