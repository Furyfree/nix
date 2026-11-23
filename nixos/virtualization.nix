# Docker for development, and QEMU/KVM for guests managed with vm-curator
# (nix run nixpkgs#vm-curator).
{ pkgs, ... }:

let
  # Docker's own rules route published ports past the firewall, so they
  # listen on localhost unless a port names another address: ip on the
  # default network, the bridge option on networks Compose and
  # `docker network create` make.
  localPorts = {
    ip = "127.0.0.1";
    default-network-opts.bridge."com.docker.network.bridge.host_binding_ipv4" = "127.0.0.1";
  };
in
{
  # vm-curator uses QEMU's bundled UEFI firmware; /dev/kvm is open to users.
  environment.systemPackages = with pkgs; [
    qemu_kvm
    # TPM emulation for Windows 11 guests, SPICE viewer and user networking.
    swtpm
    virt-viewer
    passt
  ];

  # `docker` reaches each user's rootless Docker, which cannot give root; the
  # system Docker runs the Windows VM and answers `sudo docker`.
  virtualisation.docker = {
    enable = true;
    daemon.settings = localPorts // {
      log-driver = "local";
    };
    rootless = {
      enable = true;
      setSocketVariable = true;
      daemon.settings = localPorts;
    };
  };
}
