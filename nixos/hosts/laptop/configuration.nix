# HP EliteBook X G1a laptop with AMD Radeon 890M graphics; Mesa and the
# shared firmware cover the GPU. The installer writes ./local with the
# detected hardware and the chosen account.
{ pkgs, ... }:

{
  imports = [
    ../../default.nix
    ../../dtu-eduroam.nix
    ../../local-ai.nix
    ../../secure-boot.nix
    # SSH server: uncomment while this host needs remote access.
    # ../../ssh.nix
    ./local/hardware-configuration.nix
  ];

  networking.hostName = "laptop";

  # Enroll with fprintd-enroll; password login stays available.
  services.fprintd.enable = true;

  # Light gaming.
  programs.gamemode.enable = true;
  environment.systemPackages = with pkgs; [
    brightnessctl
    prismlauncher
  ];

  system.stateVersion = "26.11";
}
