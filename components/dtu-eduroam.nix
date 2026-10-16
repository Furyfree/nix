# DTU eduroam, as Nimbus set it up: PEAP/MSCHAPv2 against DTU's two RADIUS
# servers and the DTU CAT CA bundle (SHA256 4044ec3c...a7c1). The login lives
# in a root-only local file that dtu-eduroam writes once.
{ lib, pkgs, ... }:

let
  secrets = "/etc/NetworkManager/dtu-eduroam.env";
  setup = pkgs.writeShellApplication {
    name = "dtu-eduroam";
    text = ''
      if [ "$#" -gt 1 ]; then
        printf '%s\n' 'usage: dtu-eduroam [1PASSWORD-ITEM]' >&2
        exit 2
      fi
      if [ "$#" -eq 1 ]; then
        username=$(op item get "$1" --fields label=username --reveal)
        password=$(op item get "$1" --fields label=password --reveal)
      else
        read -rp 'DTU username (for example s123456): ' username
        read -rsp 'DTU password: ' password
        printf '\n'
      fi
      case $username in *@*) ;; *) username="$username@dtu.dk" ;; esac
      # systemd's double-quoted EnvironmentFile values escape \ and ".
      quote() { printf '"%s"' "$(printf '%s' "$1" | sed 's/[\\"]/\\&/g')"; }
      # One approval writes the file from stdin and reloads the profile, so
      # the password never appears in a command line.
      printf 'DTU_USERNAME=%s\nDTU_PASSWORD=%s\n' "$(quote "$username")" "$(quote "$password")" |
        pkexec ${lib.getExe install}
      printf '%s\n' 'DTU eduroam is ready; it connects when eduroam is in range.'
    '';
  };
  install = pkgs.writeShellApplication {
    name = "dtu-eduroam-install";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
      install -D -m 0600 -o root -g root /dev/stdin ${secrets}
      systemctl restart NetworkManager-ensure-profiles.service
    '';
  };
in
{
  environment.systemPackages = [ setup ];

  networking.networkmanager.ensureProfiles = {
    environmentFiles = [ secrets ];
    profiles.dtu-eduroam = {
      connection = {
        id = "DTU eduroam";
        type = "wifi";
      };
      wifi = {
        ssid = "eduroam";
        mode = "infrastructure";
      };
      wifi-security.key-mgmt = "wpa-eap";
      "802-1x" = {
        eap = "peap";
        phase2-auth = "mschapv2";
        identity = "$DTU_USERNAME";
        password = "$DTU_PASSWORD";
        anonymous-identity = "anonymous@dtu.dk";
        ca-cert = "${./dtu-eduroam-ca.pem}";
        domain-match = "ait-pisepsn03.win.dtu.dk;ait-pisepsn04.win.dtu.dk";
      };
      ipv4.method = "auto";
      ipv6.method = "auto";
    };
  };

  # Until dtu-eduroam has written the login, skip the profile instead of
  # failing at every boot.
  systemd.services.NetworkManager-ensure-profiles.unitConfig.ConditionPathExists = secrets;
}
