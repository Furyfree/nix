# Secure Boot with your own key, so Windows anti-cheat sees it on while
# NixOS still boots. Installing creates the key and signs Limine; with Secure
# Boot still off, nothing changes. Then once per machine: set the firmware to
# Setup Mode, run `sudo sbctl enroll-keys -m` (-m keeps Microsoft's keys for
# Windows and GPU firmware) and turn Secure Boot on. Windows asks for the
# BitLocker recovery key once.
{ pkgs, ... }:

{
  boot.loader.limine = {
    secureBoot = {
      enable = true;
      autoGenerateKeys = true;
    };
    # Refuse kernels and initrds whose checksum differs from the signed config.
    panicOnChecksumMismatch = true;
  };

  environment.systemPackages = [ pkgs.sbctl ];
}
