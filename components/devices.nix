# AirPods through the LibrePods fork that Noctalia's airpods plugin uses,
# browser access to NuPhy and Wooting keyboard settings, and external monitor
# brightness through ddcutil.
{ pkgs, ... }:

{
  # The harveywuk fork adds the status file, librepods-ctl commands and the
  # headless daemon; the patch is the one the COPR package carried.
  nixpkgs.overlays = [
    (_: prev: {
      librepods = prev.librepods.overrideAttrs (old: {
        version = "0-unstable-2026-08-26";
        src = prev.fetchFromGitHub {
          owner = "harveywuk";
          repo = "librepods";
          rev = "4ed49df0b301ac3e6fba9c81dfbbb6726cc52201";
          hash = "sha256-Ygoqz5lnGMwZkys+Q4c4pyAUI0llvpGZ/ij5E91CkAg=";
        };
        sourceRoot = "source";
        patches = [ ./librepods-fix-a2dp-profile-selection.patch ];
        buildInputs = old.buildInputs ++ [ prev.qt6.qtdeclarative ];
        cmakeFlags = [ (prev.lib.cmakeBool "BUILD_TESTING" true) ];
        doCheck = true;
        preCheck = ''
          export QT_QPA_PLATFORM=offscreen HOME=$TMPDIR XDG_RUNTIME_DIR=$TMPDIR/run
          mkdir -m 0700 -p $XDG_RUNTIME_DIR
        '';
      });
    })
  ];

  environment.systemPackages = [
    pkgs.librepods
    pkgs.ddcutil
  ];

  # Loads i2c-dev and creates the i2c group that ddcutil's rules use.
  hardware.i2c.enable = true;

  # The COPR package's user unit; it skips machines without Bluetooth.
  systemd.user.services.librepods = {
    description = "librepods AirPods daemon";
    # The AAP link needs BlueZ and a session bus from the graphical session.
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    unitConfig.ConditionPathExistsGlob = "/sys/class/bluetooth/hci*";
    # Qt's debug category fires on every BLE advertisement.
    environment.QT_LOGGING_RULES = "openpods.debug=false";
    serviceConfig = {
      ExecStart = "${pkgs.librepods}/bin/librepods --headless";
      Restart = "on-failure";
      RestartSec = 5;
      # The status file carries the AirPods identity.
      UMask = "0077";
      StateDirectory = "librepods";
      StateDirectoryMode = "0700";
      ConfigurationDirectory = "AirPodsTrayApp";
      ConfigurationDirectoryMode = "0700";
      ProtectSystem = "strict";
      ProtectHome = "read-only";
      # The control socket lives in the runtime directory.
      ReadWritePaths = "%t";
      PrivateTmp = true;
      NoNewPrivileges = true;
      CapabilityBoundingSet = "";
      RestrictSUIDSGID = true;
      RestrictNamespaces = true;
      LockPersonality = true;
      SystemCallArchitectures = "native";
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectKernelLogs = true;
      ProtectControlGroups = true;
      ProtectClock = true;
      ProtectHostname = true;
      RestrictAddressFamilies = "AF_UNIX AF_BLUETOOTH AF_NETLINK";
    };
  };

  # uaccess must sort before systemd's 73-seat-late.rules, so these keep their
  # 70- names instead of NixOS's 99-local.rules. Replug keyboards after a rebuild.
  services.udev.packages = [
    # Monitor control for the logged-in user; sorts before 73-seat-late.
    pkgs.ddcutil
    (pkgs.writeTextDir "lib/udev/rules.d/70-nuphy.rules" ''
      # NuPhy IO over WebHID: grant the logged-in user the settings channel only.
      # ATTRS must match one parent, so use IDs from 60-persistent-hidraw.rules.
      KERNEL=="hidraw*", ENV{ID_VENDOR_ID}=="19f5", ENV{ID_USB_INTERFACE_NUM}=="03", TAG+="uaccess"
      # NuPhy firmware updater mode.
      KERNEL=="hidraw*", ATTRS{idVendor}=="19f5", ATTRS{idProduct}=="0722", TAG+="uaccess"
    '')
    (pkgs.writeTextDir "lib/udev/rules.d/70-wooting.rules" ''
      # Wootility over WebHID/WebUSB: Wooting's generic rules, for the logged-in user.
      # https://help.wooting.io/article/147-configuring-device-access-for-wootility-under-linux-udev-rules
      SUBSYSTEM=="hidraw", ATTRS{idVendor}=="31e3", MODE:="0660", GROUP="input", TAG+="uaccess"
      SUBSYSTEM=="usb", ATTRS{idVendor}=="31e3", MODE:="0660", GROUP="input", TAG+="uaccess"
    '')
  ];
}
