{
  self,
  lib,
  pkgs,
  modulesPath,
  ...
}:

let
  setup = pkgs.writers.writePython3Bin "nixos-setup" {
    libraries = [ pkgs.python3Packages.questionary ];
    makeWrapperArgs = [
      "--prefix"
      "PATH"
      ":"
      (lib.makeBinPath [
        pkgs.util-linux
        pkgs.openssh
      ])
    ];
  } ../../scripts/install.py;
in
{
  imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix") ];

  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "nixos-installer";
  console.keyMap = "dk";
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  environment.systemPackages = [ setup ];
  programs.bash.loginShellInit = ''
    if [[ $- == *i* && -z "''${SSH_CONNECTION:-}" ]] &&
       [[ "$(tty)" == /dev/tty1 && "$(id -un)" == nixos ]]; then
      ${setup}/bin/nixos-setup || true
    fi
  '';

  # TODO: The install stage must save the chosen user, wheel/networkmanager groups,
  # public key and Home Manager mapping in the target host config. Set passwords
  # inside the target with native tools; never put them in the repo or Nix store.
  # Live ISO SSH access is separate: add a key to the temporary nixos account locally
  # after boot. Without an authorized key, remote SSH access is unavailable.

  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
    PermitRootLogin = "no";
  };

  environment.etc."nixos-config".source = lib.cleanSourceWith {
    src = self.outPath;
    filter =
      path: type:
      lib.cleanSourceFilter path type
      && !(builtins.elem (builtins.baseNameOf path) [
        ".venv"
        ".ruff_cache"
        ".pytest_cache"
        "__pycache__"
        ".direnv"
        ".ropeproject"
      ]);
  };
  isoImage.squashfsCompression = "zstd -Xcompression-level 3";
}
