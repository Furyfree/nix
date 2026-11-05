{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Niri-style workspace overview, built against the system's Hyprland as the
  # plugin's own flake does. Bump it if a Hyprland update stops it compiling.
  scrolloverview = pkgs.hyprlandPlugins.mkHyprlandPlugin {
    hyprland = config.programs.hyprland.package;
    pluginName = "scrolloverview";
    version = "0-unstable-2026-11-05";
    src = pkgs.fetchFromGitHub {
      owner = "yayuuu";
      repo = "hyprland-scroll-overview";
      rev = "3eb62e3e0093d54cbdcf4f58c831b5b53b3b1ff2";
      hash = "sha256-0mBYt+dkLeXonsVLKs8mfsNbMQ1Zqvzf0r8VOteXni4=";
    };
    buildInputs = [ pkgs.lua5_4 ];
    enableParallelBuilding = true;
    dontUseCmakeConfigure = true;
    buildPhase = ''
      runHook preBuild
      export SCROLLOVERVIEW_BUILD_VERSION=3eb62e3
      make all
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      install -D scrolloverview.so $out/lib/libscrolloverview.so
      runHook postInstall
    '';
    meta = {
      homepage = "https://github.com/yayuuu/hyprland-scroll-overview";
      license = lib.licenses.bsd3;
    };
  };
in
{
  # A fixed path for overview.lua's hl.plugin.load.
  environment.etc."hypr/plugins/scrolloverview.so".source =
    "${scrolloverview}/lib/libscrolloverview.so";
}
