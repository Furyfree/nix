# HP EliteBook X G1a laptop with AMD Radeon 890M graphics; Mesa and the
# shared firmware cover the GPU. The installer writes ./local with the
# detected hardware and the chosen account.
{ pkgs, ... }:

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

  system.stateVersion = "26.11";
}
