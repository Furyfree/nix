# Windows 11 in Dockur's QEMU/KVM container (Nimbus #33 design). Nothing runs
# until `windows-vm install` creates the subvolume, settings and launcher on a
# machine; the container then starts on demand and is reached over local RDP.
# bin/windows-vm.nix holds the script, the service and the polkit rule, which
# Ubuntu shares.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  docker = config.virtualisation.docker.package;
  windows-vm = import ../bin/windows-vm.nix {
    inherit pkgs;
    tools = [
      docker
      pkgs.btrfs-progs
      pkgs.systemd
    ];
  };
  inherit (windows-vm.passthru) root service;
  unit = windows-vm.passthru.unit {
    exe = lib.getExe windows-vm;
    docker = lib.getExe docker;
  };
in
{
  # nofail keeps machines without the subvolume bootable; the container then
  # refuses to start instead of filling root snapshots.
  fileSystems.${root} = {
    inherit (config.fileSystems."/") device;
    fsType = "btrfs";
    options = [
      "subvol=windows"
      "compress=zstd"
      "nofail"
    ];
  };

  systemd.services.${service} = {
    unitConfig = unit.Unit;
    serviceConfig = unit.Service;
    # A rebuild must not shut down a running VM; changes apply at the next launch.
    restartIfChanged = false;
  };

  security.polkit.extraConfig = windows-vm.passthru.polkitRule;

  # Installer-selected users come from Home Manager, so no username is
  # written here.
  users.groups.windows-vm = { };
  users.users = lib.genAttrs (builtins.attrNames config.home-manager.users) (_: {
    extraGroups = [ "windows-vm" ];
  });

  environment.systemPackages = [ windows-vm ];
}
