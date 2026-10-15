# Windows 11 in Dockur's QEMU/KVM container (Nimbus #33 design). Nothing runs
# until `windows-vm install` creates the subvolume, settings and launcher on a
# machine; the container then starts on demand and is reached over local RDP.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  root = "/var/lib/windows";
  inherit (config.virtualisation.oci-containers.containers.windows) serviceName;
  windows-vm = pkgs.writeShellApplication {
    name = "windows-vm";
    runtimeInputs = with pkgs; [
      btrfs-progs
      coreutils
      e2fsprogs
      freerdp
      gawk
      gum
      jq
      systemd
      util-linux
    ];
    runtimeEnv = {
      WINDOWS_ROOT = root;
      WINDOWS_SERVICE = "${serviceName}.service";
    };
    text = builtins.readFile ./windows-vm.sh;
  };
in
{
  # nofail keeps machines without the subvolume bootable; the container then
  # refuses to start instead of filling root snapshots.
  fileSystems.${root} = {
    inherit (config.fileSystems."/") device;
    fsType = "btrfs";
    options = [
      "subvol=windows"
      "compress=zstd"
      "nofail"
    ];
  };

  virtualisation.oci-containers = {
    backend = "docker";
    containers.windows = {
      image = "docker.io/dockurr/windows:6.06";
      autoStart = false;
      # settings.env from `windows-vm install` adds RAM_SIZE, CPU_CORES,
      # DISK_SIZE, USERNAME, PASSWORD and TZ. A storage/custom.iso replaces
      # the VERSION download.
      environment = {
        VERSION = "11";
        KEYBOARD = "da-DK";
        REGION = "en-DK";
        # The web console asks for the Windows username and password.
        PROTECT = "Y";
        # Windows keeps the hardware clock in local time.
        ARGUMENTS = "-rtc base=localtime,clock=host,driftfix=slew";
      };
      environmentFiles = [ "${root}/settings.env" ];
      ports = [
        "127.0.0.1:8006:8006"
        "127.0.0.1:3389:3389/tcp"
        "127.0.0.1:3389:3389/udp"
      ];
      volumes = [
        "${root}/storage:/storage"
        "${root}/shared:/shared"
      ];
      devices = [
        "/dev/kvm"
        "/dev/net/tun"
      ];
      capabilities.NET_ADMIN = true;
      # Give Windows time to shut down cleanly.
      extraOptions = [ "--stop-timeout=120" ];
    };
  };
  systemd.services.${serviceName} = {
    unitConfig.RequiresMountsFor = root;
    # A rebuild must not shut down a running VM; changes apply at the next launch.
    restartIfChanged = false;
    serviceConfig = {
      TimeoutStopSec = lib.mkForce 150;
      # docker stop ends the container with SIGTERM.
      SuccessExitStatus = 143;
    };
  };

  # The docker group (already root-equivalent) may start and stop this VM.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") == "${serviceName}.service" &&
          subject.isInGroup("docker")) {
        return polkit.Result.YES;
      }
    });
  '';

  environment.systemPackages = [ windows-vm ];
}
