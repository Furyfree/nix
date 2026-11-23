_:

{
  networking.networkmanager = {
    enable = true;
    # iwd instead of wpa_supplicant: the laptop's MT7925 timed out WPA3's
    # 6 GHz handshake (reason 15), which NetworkManager read as a wrong
    # password.
    wifi.backend = "iwd";
  };

  # A service that asks for network-online.target would hold auto-login until
  # the link and DHCP are up; nothing here needs the network at boot.
  systemd.services.NetworkManager-wait-online.enable = false;
}
