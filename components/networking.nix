_:

{
  networking.networkmanager = {
    enable = true;
    # iwd instead of wpa_supplicant: the laptop's MT7925 timed out WPA3's
    # 6 GHz handshake (reason 15), which NetworkManager read as a wrong
    # password.
    wifi.backend = "iwd";
  };

  # As on Fedora: Docker orders graphical.target behind network-online.target,
  # so auto-login waited for the link and DHCP. Nothing here needs the network
  # at boot.
  systemd.services.NetworkManager-wait-online.enable = false;
}
