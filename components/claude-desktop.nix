# Anthropic's official Claude Desktop for Linux, from its signed apt repository.
# To update, take the version and SHA256 from
# https://downloads.claude.ai/claude-desktop/apt/stable/dists/stable/main/binary-amd64/Packages
# after checking dists/stable/InRelease against Anthropic's key
# 31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE.
{ lib, pkgs, ... }:

let
  claude-desktop = pkgs.stdenv.mkDerivation (finalAttrs: {
    pname = "claude-desktop";
    version = "2.42304.0";

    src = pkgs.fetchurl {
      url = "https://downloads.claude.ai/claude-desktop/apt/stable/pool/main/c/claude-desktop/claude-desktop_${finalAttrs.version}_amd64.deb";
      hash = "sha256-dM0szCnSQWUUTkVcvIcsbMKiSiY7g+c0IOlfiRZtSqQ=";
    };

    nativeBuildInputs = with pkgs; [
      dpkg
      autoPatchelfHook
      makeWrapper
    ];

    # The bundled Electron's libraries, after nixpkgs' beekeeper-studio, the
    # package's own Depends, and libseccomp and libcap-ng for Cowork's virtiofsd.
    buildInputs = with pkgs; [
      (lib.getLib stdenv.cc.cc)
      alsa-lib
      at-spi2-atk
      cairo
      cups
      dbus
      expat
      gdk-pixbuf
      glib
      gtk3
      libcap_ng
      libdrm
      libgbm
      libGL
      libnotify
      libseccomp
      libsecret
      libuuid
      libx11
      libxcb
      libxcomposite
      libxdamage
      libxext
      libxfixes
      libxkbcommon
      libxrandr
      libxtst
      nspr
      nss
      pango
      pipewire
      vulkan-loader
    ];

    runtimeDependencies = [ (lib.getLib pkgs.systemdLibs) ];

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      cp -r usr/lib usr/share $out/
      # Store files cannot be setuid; Electron uses user namespaces instead.
      rm $out/lib/claude-desktop/chrome-sandbox
      # As the COPR launcher did: keep the sign-in in the GNOME keyring rather
      # than in a file Electron leaves unencrypted on unrecognised desktops.
      makeWrapper $out/lib/claude-desktop/claude-desktop $out/bin/claude-desktop \
        --add-flags "--password-store=gnome-libsecret" \
        --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}"
      runHook postInstall
    '';

    preFixup = ''
      patchelf --add-needed libGL.so.1 --add-needed libEGL.so.1 \
        --add-rpath ${lib.makeLibraryPath [ pkgs.libGL ]} \
        $out/lib/claude-desktop/claude-desktop
    '';

    meta = {
      description = "Anthropic's desktop app for Claude";
      homepage = "https://claude.ai/download";
      license = lib.licenses.unfree;
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
      mainProgram = "claude-desktop";
      platforms = [ "x86_64-linux" ];
    };
  });
in
{
  environment.systemPackages = [ claude-desktop ];
}
