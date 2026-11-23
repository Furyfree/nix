# Desktop applications that need no sign-in.
{ inputs, pkgs, ... }:

let
  # Strata replaces Nautilus as the file manager:
  # https://github.com/Furyfree/nix/issues/18. Its FileManager1 service answers
  # "Show in folder". File dialogs stay GTK's, since Strata's chooser handles
  # local files only (strata#176).
  strata = inputs.strata.packages.${pkgs.stdenv.hostPlatform.system}.default;
  # Chrome-based apps list their contents for computer-use-linux only with this
  # flag. Signal and Fastmail stay without, so other programs cannot read them.
  accessible = pkg: pkg.override { commandLineArgs = "--force-renderer-accessibility"; };
in
{
  programs = {
    gnome-disks.enable = true;
    # Opens its port 53317 for receiving.
    localsend.enable = true;
    # The headless Chrome T3 Code downloads for its previews.
    nix-ld.libraries = with pkgs; [
      alsa-lib
      at-spi2-core
      dbus
      expat
      glib
      libgbm
      libx11
      libxcb
      libxcomposite
      libxdamage
      libxext
      libxfixes
      libxkbcommon
      libxrandr
      nspr
      nss
    ];
    obs-studio.enable = true;
  };

  services = {
    # Phones (MTP), network shares (SMB) and trash for the file manager.
    gvfs.enable = true;
    dbus.packages = [ strata.fileManagerService ];
  };

  environment.systemPackages = with pkgs; [
    strata
    loupe
    gnome-calculator
    celluloid
    pinta
    libreoffice
    (accessible vscode)
    t3code
    (accessible brave-origin)
    signal-desktop
    discord
    spotify
    (accessible obsidian)
    fastmail-desktop
    woeusb
    jetbrains-toolbox
    surfer
  ];

  nixpkgs.config.allowUnfreePackages = [
    "discord"
    "discord-unwrapped"
    "spotify"
    "obsidian"
    "fastmail-desktop"
    "jetbrains-toolbox"
    "vscode"
  ];

  # Surfer's package ships no menu entry; the icon is upstream's own (EUPL-1.2).
  home-manager.sharedModules = [
    {
      xdg.dataFile."icons/hicolor/scalable/apps/surfer.svg".source =
        "${pkgs.surfer.src}/surfer/assets/logo-small.svg";
      xdg.desktopEntries.surfer = {
        name = "Surfer";
        genericName = "Waveform viewer";
        exec = "surfer %f";
        icon = "surfer";
        settings.Keywords = "VCD;waveform;Chisel;Verilog";
      };
    }
  ];
}
