# System configuration for the Linux desktop.
# Import ../../system.nix for the shared defaults.
# Import ./hardware-configuration.nix for this machine's hardware and disks.
# Set the hostname and add desktop-specific packages or services here.
# Example: add Gimp here if only the desktop needs it.
{ ... }:

{
  imports = [
    ../../components/filesystems.nix
    (import ../../components/swap.nix { sizeGiB = 48; })
  ];
}
