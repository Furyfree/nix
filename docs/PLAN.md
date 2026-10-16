# Plan

Open work only; finished work lives in Git.

## Move onto NixOS

1. Install the laptop, then the desktop, with [INSTALLATION.md](../INSTALLATION.md)
   and run its checks.
2. Add the OpenRouter key to ai-usagebar's config and the Fastmail calendar in
   Noctalia's settings when wanted.
3. Then retire Fedora, Nimbus, Chezmoi, COPR and fedora-iso.

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
