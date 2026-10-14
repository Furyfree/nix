# Windows 11 in Dockur's QEMU/KVM container (Nimbus #33 design), started on
# demand by the windows-vm launcher and reached over local RDP.
# Per machine, outside Git: credentials.env (USERNAME=… and PASSWORD=…, owned
# root:docker, mode 0640) and an optional storage/custom.iso for the install.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  root = "/var/lib/windows";
  service = "${config.virtualisation.oci-containers.containers.windows.serviceName}.service";
  launcher = pkgs.writeShellApplication {
    name = "windows-vm";
    runtimeInputs = with pkgs; [
      freerdp
      libnotify
      systemd
    ];
    text = ''
      # shellcheck source=/dev/null
      . ${root}/credentials.env
      rdp() {
        printf '%s\n' "$PASSWORD" |
          sdl-freerdp /v:127.0.0.1 /u:"$USERNAME" /from-stdin:force /cert:ignore "$@"
      }

      systemctl start ${service}
      trap 'systemctl stop ${service}' EXIT
      notify-send "Windows VM" "Starting. The first start installs Windows: follow it at http://127.0.0.1:8006"
      until rdp /auth-only >/dev/null 2>&1; do
        systemctl is-active --quiet ${service} || exit 1
        sleep 10
      done
      rdp /f +dynamic-resolution +clipboard
    '';
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
  systemd.tmpfiles.rules = [
    "d ${root}/storage 0700 root root -"
    "d ${root}/shared 2775 root docker -"
  ];

  virtualisation.oci-containers = {
    backend = "docker";
    containers.windows = {
      image = "docker.io/dockurr/windows:6.06";
      autoStart = false;
      # A storage/custom.iso replaces the VERSION download.
      environment = {
        VERSION = "11";
        RAM_SIZE = "8G";
        CPU_CORES = "4";
        DISK_SIZE = "128G";
        KEYBOARD = "da-DK";
        REGION = "en-DK";
      };
      environmentFiles = [ "${root}/credentials.env" ];
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
  systemd.services.${config.virtualisation.oci-containers.containers.windows.serviceName} = {
    unitConfig.RequiresMountsFor = root;
    serviceConfig.TimeoutStopSec = lib.mkForce 150;
  };

  # The docker group (already root-equivalent) may start and stop this VM.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") == "${service}" &&
          subject.isInGroup("docker")) {
        return polkit.Result.YES;
      }
    });
  '';

  environment.systemPackages = [ launcher ];
}
