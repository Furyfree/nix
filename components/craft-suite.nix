# Craft apps from storytold's Linux release tarballs, each with its headless
# CLI and MCP server; ../pins/ holds their versions and npin bumps them.
{ lib, pkgs, ... }:

let
  sources = pkgs.callPackage ../pins/_sources/generated.nix { };

  mkCraftApp =
    pname: description:
    pkgs.stdenv.mkDerivation {
      inherit (sources.${pname}) pname version src;

      nativeBuildInputs = [ pkgs.autoPatchelfHook ];

      buildInputs = with pkgs; [
        (lib.getLib stdenv.cc.cc)
        alsa-lib
      ];

      # Window, GPU and portal libraries the apps open at run time.
      runtimeDependencies = with pkgs; [
        dbus
        libGL
        (lib.getLib libva)
        libx11
        libxcb
        libxcursor
        libxi
        libxkbcommon
        vulkan-loader
        wayland
      ];

      # Copy the app tree only; its install.sh writes into ~/.local.
      installPhase = ''
        runHook preInstall
        mkdir -p $out
        cp -r bin share $out/
        runHook postInstall
      '';

      # The NVIDIA driver's Vulkan, NVDEC and NVENC libraries.
      appendRunpaths = [ "${pkgs.addDriverRunpath.driverLink}/lib" ];

      meta = {
        inherit description;
        homepage = "https://github.com/storytold/${pname}";
        license = with lib.licenses; [
          mit
          asl20
        ];
        sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
        mainProgram = pname;
        platforms = [ "x86_64-linux" ];
      };
    };
in
{
  environment.systemPackages = lib.mapAttrsToList mkCraftApp {
    filmcraft = "Video editor";
    effectcraft = "Motion graphics and compositing";
    soundcraft = "Audio editor and mixer";
    photocraft = "Raster image editor";
  };
}
