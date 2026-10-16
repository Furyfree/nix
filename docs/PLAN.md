# Plan

Open work only; finished work lives in Git.

## Move onto NixOS

1. Install the laptop, then the desktop, with [INSTALLATION.md](../INSTALLATION.md)
   and run its checks.
2. Add the OpenRouter key to ai-usagebar's config and the Fastmail calendar in
   Noctalia's settings when wanted.
3. Then retire Fedora, Nimbus, Chezmoi, COPR and fedora-iso.
4. Watch laptop Wi-Fi after boot. Fedora needed a one-time retry because the
   MT7925 card could fail its first handshake; NixOS starts without it. The
   Fedora unit, ported once, failed on the laptop because it was on Ethernet
   with no saved Wi-Fi network to connect, not because of the card. Bring a
   retry back only if Wi-Fi fails at boot, and skip it when no network is
   saved.
5. Remove the temporary SSH server from `hosts/laptop/configuration.nix` once
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

- macOS: standalone Home Manager for the shared configs; Swift mac-setup owns
  native apps and settings. Confirm architecture, user paths and installer
  before enabling.
- WSL: NixOS-WSL with integrated Home Manager and selected Linux tools.
  win-setup owns Windows setup and apps; test editor server compatibility and
  keep Terminal profiles and Zed local values in backed-up Windows copies.
