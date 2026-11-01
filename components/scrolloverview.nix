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
    version = "0-unstable-2026-10-28";
    src = pkgs.fetchFromGitHub {
      owner = "yayuuu";
      repo = "hyprland-scroll-overview";
      rev = "07a944e4d16f11d2d9be6ce10bea74a6f1e5f2ae";
      hash = "sha256-M4NbHbRn/YGDGP54ts/WGxPjQhZMcGy1cIqQ5D89C3E=";
    };
    buildInputs = [ pkgs.lua5_4 ];
    enableParallelBuilding = true;
    dontUseCmakeConfigure = true;
    buildPhase = ''
      runHook preBuild
      export SCROLLOVERVIEW_BUILD_VERSION=6b59bd8
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
