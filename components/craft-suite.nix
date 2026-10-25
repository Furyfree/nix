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
      version = "0.13.0";
      hash = "sha256-QOnWhfs+0bCiHJwCIR8ahJngmkfFUSRM5+6A8lhNOps=";
      description = "Video editor";
    }
    {
      pname = "effectcraft";
      version = "0.17.0";
      hash = "sha256-zXrODXRzS3noUfGFN8FLKVO3/rXaJA9QBeaAVHahUpI=";
      description = "Motion graphics and compositing";
    }
    {
      pname = "soundcraft";
      version = "0.13.1";
      hash = "sha256-Ce5siEWTT+70u/TFwOLw/8o/yREm/XpqQGGx+DkHRW0=";
      description = "Audio editor and mixer";
    }
    {
      pname = "photocraft";
      version = "0.16.0";
      hash = "sha256-fBfzYz6/favydiji0mN9kYx8KlsWO4uQNHp4rN32Ngg=";
      description = "Raster image editor";
    }
  ];
}
