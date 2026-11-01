# Desktop applications that need no sign-in.
{ pkgs, ... }:

let
  # Chrome-based apps list their contents for computer-use-linux only with this
  # flag. Signal and Fastmail stay without, so other programs cannot read them.
  accessible = pkg: pkg.override { commandLineArgs = "--force-renderer-accessibility"; };
in
{
  programs = {
    gnome-disks.enable = true;
    # Opens its port 53317 for receiving.
    localsend.enable = true;
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
    (accessible vscodium)
    t3code
    (accessible brave-origin)
    signal-desktop
    vesktop
    spotify
    (accessible obsidian)
    fastmail-desktop
    woeusb
    jetbrains-toolbox
  ];
}
