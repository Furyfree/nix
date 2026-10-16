# Network printing and scanning, as Nimbus set up for the Epson ET-5800: CUPS
# prints driverless (IPP Everywhere) and sane-airscan scans without drivers.
{ pkgs, ... }:

{
  services.printing.enable = true;

  # Find network printers and scanners, and resolve their .local names.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  hardware.sane = {
    enable = true;
    extraBackends = [ pkgs.sane-airscan ];
  };

  environment.systemPackages = [ pkgs.simple-scan ];
}
