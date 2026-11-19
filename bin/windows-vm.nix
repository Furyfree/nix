# windows-vm with its tools, for NixOS (nixos/windows-vm.nix) and Ubuntu
# (ubuntu/home.nix). Each adds what its own system must provide: NixOS its
# Docker, systemd and btrfs-progs; Ubuntu uses the ones from apt.
{
  pkgs,
  tools ? [ ],
}:

let
  root = "/var/lib/windows";
  service = "docker-windows";
in
pkgs.writeShellApplication {
  name = "windows-vm";
  runtimeInputs =
    with pkgs;
    [
      coreutils
      e2fsprogs
      freerdp
      gawk
      gum
      jq
      util-linux
      xmlstarlet
    ]
    ++ tools;
  runtimeEnv = {
    WINDOWS_ROOT = root;
    WINDOWS_SERVICE = "${service}.service";
  };
  text = builtins.readFile ./windows-vm;
  passthru = {
    inherit root service;
    # The system service both systems run, after Docker, so it stops first at
    # shutdown and Windows gets the container's 120 seconds. EXE is this
    # package's windows-vm, DOCKER the system's docker command.
    unit =
      { exe, docker }:
      {
        Unit = {
          Description = "Windows VM";
          After = "docker.service docker.socket network-online.target";
          Wants = "network-online.target";
          RequiresMountsFor = root;
        };
        Service = {
          ExecStartPre = "-${docker} rm -f windows";
          ExecStart = "${exe} run";
          ExecStop = "-${docker} stop windows";
          ExecStopPost = "-${docker} rm -f windows";
          Restart = "on-failure";
          # docker stop ends the container with SIGTERM.
          SuccessExitStatus = 143;
          TimeoutStartSec = 0;
          TimeoutStopSec = 150;
        };
      };
    # The docker group, already root-equivalent, may start and stop it.
    polkitRule = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            action.lookup("unit") == "${service}.service" &&
            subject.isInGroup("docker")) {
          return polkit.Result.YES;
        }
      });
    '';
  };
}
