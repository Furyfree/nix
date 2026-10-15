_:

{
  networking.networkmanager.enable = true;

  # As on Fedora: Docker orders graphical.target behind network-online.target,
  # so auto-login waited for the link and DHCP. Nothing here needs the network
  # at boot.
  systemd.services.NetworkManager-wait-online.enable = false;
}
