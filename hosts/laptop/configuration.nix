# HP EliteBook X G1a laptop with AMD Radeon 890M graphics; Mesa and the
# shared firmware cover the GPU. The installer writes ./local with the
# detected hardware and the chosen account.
{ lib, pkgs, ... }:

{
  imports = [
    ../../system.nix
    ../../components/dtu-eduroam.nix
    ../../components/secure-boot.nix
    ./local/hardware-configuration.nix
  ];

  networking.hostName = "laptop";

  # Temporary, for remote fixes after the install on the home network; remove
  # with its docs/PLAN.md item.
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "no";
  };

  # Enroll with fprintd-enroll; password login stays available.
  services.fprintd.enable = true;

  # Light gaming, as on Fedora.
  programs.gamemode.enable = true;
  environment.systemPackages = with pkgs; [
    brightnessctl
    prismlauncher
  ];

  # The MT7925 card can fail its first handshake at boot; retry once. nmcli
  # reuses the saved connection, so no password is stored here.
  systemd.services.wifi-retry = {
    description = "Retry laptop Wi-Fi once after boot";
    wants = [ "NetworkManager.service" ];
    after = [ "NetworkManager.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.networkmanager ];
    environment.LC_ALL = "C";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = 90;
      ExecStartPre = "${lib.getExe' pkgs.coreutils "sleep"} 8";
    };
    script = ''
      nmcli -t -f DEVICE,TYPE,STATE device status |
        while IFS=: read -r device type state; do
          case "$type:$state" in
            wifi:disconnected | wifi:failed | wifi:connecting*)
              nmcli --wait 30 device connect "$device"
              ;;
          esac
        done
    '';
  };

  system.stateVersion = "26.11";
}
