# Computer use for agents, from agent-sh's prebuilt release binaries:
# computer-use-linux drives the real desktop, agent-workspace-linux runs a
# hidden desktop of the agent's own. Both are MCP servers. To update, take the
# version from https://github.com/agent-sh/<tool>/releases and each binary's
# hash from its .sha256 file (`nix hash convert --hash-algo sha256 <hex>`).
{
  config,
  lib,
  pkgs,
  ...
}:

let
  release =
    repo: version: binary: hash:
    pkgs.fetchurl {
      url = "https://github.com/agent-sh/${repo}/releases/download/v${version}/${binary}-x86_64-unknown-linux-gnu";
      inherit hash;
    };

  meta = pname: description: {
    inherit description;
    homepage = "https://github.com/agent-sh/${pname}";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = pname;
    platforms = [ "x86_64-linux" ];
  };

  # Programs the hidden desktop may launch. The system paths match the
  # installed apps, flags included. Signal, Fastmail and 1Password stay out
  # so agents cannot read them unseen; Ghostty and Claude Desktop stay out
  # because a shell or another Claude session would get around the agents'
  # permission prompts. VSCodium's terminal is barred only by the skill.
  permissions = pkgs.writeText "agent-workspace-permissions.json" (
    builtins.toJSON {
      apps.allow = [
        (lib.getExe pkgs.brave-origin)
      ]
      ++ map (name: "/run/current-system/sw/bin/${name}") [
        "obsidian"
        "codium"
        "windows-vm"
      ];
    }
  );

  computer-use-linux =
    let
      pname = "computer-use-linux";
      version = "0.7.47";
      server = release pname version pname "sha256-aclY1JTHwHY1YGLfPIQA/DXmwrEOON971+wNIWOwUNI=";
      indicator =
        release pname version "${pname}-indicator"
          "sha256-6VooPi8MDTDSHJbHXq1KHeaelIPdf2ag/Y1V1hVnTrc=";
    in
    pkgs.stdenv.mkDerivation {
      inherit pname version;
      dontUnpack = true;

      nativeBuildInputs = with pkgs; [
        autoPatchelfHook
        makeWrapper
      ];

      # Opened at run time to check that text fits the keymap.
      runtimeDependencies = [ pkgs.libxkbcommon ];

      # The server finds the on-screen indicator next to itself. hyprctl comes
      # from the Hyprland session. complete_interaction tells me with a
      # notification when an agent has finished, since the indicator hides
      # between actions.
      installPhase = ''
        runHook preInstall
        install -Dm755 ${server} $out/bin/computer-use-linux
        install -Dm755 ${indicator} $out/bin/computer-use-linux-indicator
        wrapProgram $out/bin/computer-use-linux \
          --prefix PATH : ${
            lib.makeBinPath (
              with pkgs;
              [
                grim
                libnotify
                wtype
                ydotool
              ]
            )
          } \
          --set-default COMPUTER_USE_LINUX_NOTIFY_ON_COMPLETE 1
        runHook postInstall
      '';

      meta = meta pname "Control the real desktop for AI agents";
    };

  agent-workspace-linux =
    let
      pname = "agent-workspace-linux";
      version = "0.6.3";
    in
    pkgs.stdenv.mkDerivation {
      inherit pname version;
      src = release pname version pname "sha256-Zm0AO38Xr3/2h5hCzWjteCd5psqCBMiYUYVxhHDP9Js=";
      dontUnpack = true;

      nativeBuildInputs = with pkgs; [
        autoPatchelfHook
        makeWrapper
      ];

      buildInputs = with pkgs; [
        (lib.getLib stdenv.cc.cc)
        libxcb
        libxkbcommon
      ];

      # The viewer window's display and GPU libraries.
      runtimeDependencies = with pkgs; [
        libglvnd
        vulkan-loader
        wayland
      ];
      appendRunpaths = [ "${pkgs.addDriverRunpath.driverLink}/lib" ];

      # The tools behind its default X11 desktop, the app allowlist, and Brave
      # as the browser it opens with a profile of its own. Agents in T3 Code
      # inherit ELECTRON_RUN_AS_NODE, which would start Electron apps as Node.
      installPhase = ''
        runHook preInstall
        install -Dm755 $src $out/bin/agent-workspace-linux
        wrapProgram $out/bin/agent-workspace-linux \
          --prefix PATH : ${
            lib.makeBinPath (
              with pkgs;
              [
                dbus
                imagemagick
                openbox
                xauth
                xclip
                xdotool
                xdpyinfo
                xprop
                xvfb
                xwininfo
              ]
            )
          } \
          --unset ELECTRON_RUN_AS_NODE \
          --set-default AGENT_WORKSPACE_PERMISSIONS ${permissions} \
          --set-default BROWSER_BIN ${lib.getExe pkgs.brave-origin}
        runHook postInstall
      '';

      meta = meta pname "Hidden desktop for AI agents";
    };
in
{
  environment.systemPackages = [
    computer-use-linux
    agent-workspace-linux
  ];

  # Apps list their buttons and fields on the accessibility bus.
  services.gnome.at-spi2-core.enable = true;

  # Clicks need /dev/uinput, opened to the uinput group only. Any program
  # running as a member can fake input.
  hardware.uinput.enable = true;
  users.users = lib.genAttrs (builtins.attrNames config.home-manager.users) (_: {
    extraGroups = [ "uinput" ];
  });

  # Key presses and scrolling go through a per-user ydotoold, with its socket
  # in the private runtime directory where computer-use-linux looks.
  systemd.user.services.ydotoold = {
    description = "ydotool input daemon";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${lib.getExe' pkgs.ydotool "ydotoold"} --socket-path=%t/.ydotool_socket";
      Restart = "on-failure";
    };
  };
}
