# Computer use for agents, from agent-sh's prebuilt release binaries:
# computer-use-linux drives the real desktop, agent-workspace-linux runs a
# hidden desktop of the agent's own. Both are MCP servers; ./pins/ holds their
# versions and npin bumps them.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  sources = pkgs.callPackage ./pins/_sources/generated.nix { };

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
      server = sources.computer-use-linux;
      indicator = sources.computer-use-linux-indicator;
    in
    assert lib.assertMsg (server.version == indicator.version)
      "pins: computer-use-linux ${server.version} and its indicator ${indicator.version} differ; run npin computer-use-linux computer-use-linux-indicator";
    pkgs.stdenv.mkDerivation {
      inherit (server) pname version;
      dontUnpack = true;

      nativeBuildInputs = with pkgs; [
        autoPatchelfHook
        makeWrapper
      ];

      # Opened at run time to check that text fits the keymap.
      runtimeDependencies = [ pkgs.libxkbcommon ];

      # The server finds the on-screen indicator next to itself. hyprctl or
      # niri comes from the session. complete_interaction tells me with a
      # notification when an agent has finished, since the indicator hides
      # between actions.
      installPhase = ''
        runHook preInstall
        install -Dm755 ${server.src} $out/bin/computer-use-linux
        install -Dm755 ${indicator.src} $out/bin/computer-use-linux-indicator
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

      meta = meta server.pname "Control the real desktop for AI agents";
    };

  agent-workspace-linux =
    let
      inherit (sources.agent-workspace-linux) pname version src;
    in
    pkgs.stdenv.mkDerivation {
      inherit pname version src;
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
