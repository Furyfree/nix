# Craft apps from storytold's Linux release tarballs, each with its headless
# CLI and MCP server. To update, take the version from
# https://github.com/storytold/<app>/releases and the hash of
# <app>-<version>-linux-x86_64.tar.gz from that release's SHA256SUMS.txt
# (`nix hash convert --hash-algo sha256 <hex>`).
{ lib, pkgs, ... }:

let
  mkCraftApp =
    {
      pname,
      version,
      hash,
      description,
    }:
    pkgs.stdenv.mkDerivation {
      inherit pname version;

      src = pkgs.fetchurl {
        url = "https://github.com/storytold/${pname}/releases/download/v${version}/${pname}-${version}-linux-x86_64.tar.gz";
        inherit hash;
      };

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
  environment.systemPackages = map mkCraftApp [
    {
      pname = "filmcraft";
      version = "0.15.0";
      hash = "sha256-IrEGtMpilNmz6aSvQLQKZToYl0NzZIBQRqAd26pLIsE=";
      description = "Video editor";
    }
    {
      pname = "effectcraft";
      version = "0.19.0";
      hash = "sha256-fsk5Ha53X3zn5ykSaPexIzIowbreg87YhAMDU1yVGXA=";
      description = "Motion graphics and compositing";
    }
    {
      pname = "soundcraft";
      version = "0.15.0";
      hash = "sha256-Fu8j72LsIPX8xT4Eq6r/UnCV5QX1YItHqxtyscjp7SA=";
      description = "Audio editor and mixer";
    }
    {
      pname = "photocraft";
      version = "0.18.0";
      hash = "sha256-S4rI4RRqyal+e/3vFrJn1Tlqd4Cf1OIym4Pa14CGV08=";
      description = "Raster image editor";
    }
  ];
}
