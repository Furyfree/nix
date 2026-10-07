{
  self,
  config,
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
        pkgs.parted
        pkgs.cryptsetup
        pkgs.dosfstools
        pkgs.btrfs-progs
        pkgs.systemd
        config.nix.package
        pkgs.git
        config.system.build.nixos-generate-config
        config.system.build.nixos-install
        pkgs.nixos-enter
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
  systemd.services."getty@tty1" = {
    overrideStrategy = "asDropin";
    serviceConfig.ExecStart = [
      ""
      "${lib.getExe' pkgs.util-linux "agetty"} --login-program ${config.services.getty.loginProgram} --issue-file /etc/issue:/etc/issue.d:/run/issue:/run/issue.d --autologin root --noclear --keep-baud %I 115200,38400,9600 $TERM"
    ];
  };
  programs.bash.loginShellInit = ''
    if [[ $- == *i* && -z "''${SSH_CONNECTION:-}" ]] &&
       [[ "$(tty)" == /dev/tty1 && "$(id -un)" == root ]]; then
      ${setup}/bin/nixos-setup || true
    fi
  '';

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
