{ self, lib, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix") ];

  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "nixos-installer";
  console.keyMap = "dk";
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  users.users.nixos.openssh.authorizedKeys.keys =
    self.nixosConfigurations.nixos-test.config.users.users.user.openssh.authorizedKeys.keys;

  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
    PermitRootLogin = "no";
  };

  environment.etc."nixos-config".source = lib.cleanSource self.outPath;
  isoImage.squashfsCompression = "zstd -Xcompression-level 3";
}
