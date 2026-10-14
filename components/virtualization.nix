# Docker for development, and QEMU/KVM for guests managed with vm-curator.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  # vm-curator uses QEMU's bundled UEFI firmware; /dev/kvm is open to users.
  environment.systemPackages = with pkgs; [
    qemu_kvm
    # TPM emulation for Windows 11 guests, SPICE viewer and user networking.
    swtpm
    virt-viewer
    passt
  ];

  virtualisation.docker = {
    enable = true;
    daemon.settings.log-driver = "local";
  };

  # The docker group is root-equivalent, as on Fedora. Installer-selected
  # users come from Home Manager, so no username is written here.
  users.users = lib.genAttrs (builtins.attrNames config.home-manager.users) (_: {
    extraGroups = [ "docker" ];
  });
}
