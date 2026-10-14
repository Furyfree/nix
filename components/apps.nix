# Desktop applications that need no sign-in.
{ pkgs, ... }:

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
  ];
}
