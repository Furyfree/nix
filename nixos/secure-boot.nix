# Secure Boot with your own key, so Windows anti-cheat sees it on while
# NixOS still boots. Installing creates the key and signs Limine. Kernels
# and initrds carry no signature: Limine checks them against the checksums
# in its signed config, so `sbctl verify` lists them as not signed.
# Nothing is checked until the key is enrolled and Secure Boot is on, once
# per machine, as nixos/README.md's first boot step describes.
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
