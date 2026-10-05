{ config, lib, ... }:

{
  fileSystems = {
    "/" = {
      fsType = "btrfs";
      options = [ "subvol=root" "compress=zstd" ];
    };

    "/boot" = {
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };
  } // lib.mapAttrs (_: subvolume: {
    device = config.fileSystems."/".device;
    fsType = "btrfs";
    options = [ "subvol=${subvolume}" "compress=zstd" ];
  }) {
    "/home" = "home";
    "/.snapshots" = "snapshots";
    "/var/log" = "log";
    "/var/cache" = "cache";
    "/var/swap" = "swapfile";
    "/var/lib/flatpak" = "flatpak";
    "/var/lib/docker" = "docker";
    "/var/lib/containerd" = "containerd";
    "/var/lib/windows" = "windows";
  };
}
