# System configuration for the Linux laptop.
# Import ../../system.nix for the shared defaults.
# Import ./hardware-configuration.nix for this machine's hardware and disks.
# Set the hostname and add laptop-specific packages or services here.
# Example: enable fingerprint support here if the laptop needs it.
{ ... }:

{
  imports = [
    ../../components/filesystems.nix
    (import ../../components/swap.nix { sizeGiB = 96; })
  ];
}
