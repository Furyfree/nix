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

  # Enroll with fingerprint setup; password login stays available.
  services.fprintd.enable = true;

  # A closed lid suspends, then hibernates after two hours, so a laptop in a
  # bag doesn't keep the disk key in memory for days; waking from
  # hibernation asks for the disk password again.
  services.logind.settings.Login.HandleLidSwitch = "suspend-then-hibernate";
  systemd.sleep.settings.Sleep.HibernateDelaySec = "2h";

  # Light gaming.
  programs.gamemode.enable = true;
  environment.systemPackages = with pkgs; [
    brightnessctl
    prismlauncher
  ];

  system.stateVersion = "26.11";
}
