# Desktop applications that need no sign-in.
{ pkgs, ... }:

let
  # T3 Code 0.1.0 before nixpkgs has it: the same version and hashes as
  # NixOS/nixpkgs#575132. Drop this once a flake update brings 0.1.0.
  t3code = pkgs.t3code.override {
    t3code-unwrapped =
      (pkgs.callPackage "${pkgs.path}/pkgs/by-name/t3/t3code/unwrapped.nix" { }).overrideAttrs
        (
          _: prev: {
            version = "0.1.0";
            src = prev.src.override {
              tag = "v0.1.0";
              hash = "sha256-P82DqoY1E9wtROwu5Nr7MB/I1PdmZHWXXR4nRa4GWXM=";
            };
            pnpmDeps = prev.pnpmDeps.overrideAttrs {
              outputHash = "sha256-oX4tOu20tYO3ci7VvSEL8eFgxAYWp5HlQFSfAWJGJmg=";
            };
          }
        );
  };
in
{
  programs = {
    gnome-disks.enable = true;
    obs-studio.enable = true;
  };

  services = {
    # Phones (MTP), network shares (SMB) and trash for Nautilus.
    gvfs.enable = true;
    # Nautilus previews with Space.
    gnome.sushi.enable = true;
  };

  environment.systemPackages = with pkgs; [
    nautilus
    loupe
    celluloid
    mpv
    pinta
    libreoffice
    vscodium
    t3code
    brave-origin
    signal-desktop
    vesktop
    spotify
    obsidian
    fastmail-desktop
    woeusb
    jetbrains-toolbox
  ];
}
