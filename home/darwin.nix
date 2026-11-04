# Home Manager settings for macOS, run by nix-darwin. darwin/ installs the apps
# and command-line tools through Homebrew and owns system settings; this links
# the shared configs, maps them to macOS paths and sets the Mac apps' own
# settings. Builds on common.nix.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.home) homeDirectory;
  link = path: config.lib.file.mkOutOfStoreSymlink "${homeDirectory}/Projects/nix/configs/${path}";
  # 1Password's app bundle holds its SSH agent socket and Git signer.
  onePasswordAgent = "${homeDirectory}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
  onePasswordSigner = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";

  # The shared fastfetch layout with the Apple logo and without the DE row,
  # which macOS leaves empty. The Mac gets a copy, so its edits apply after a
  # switch.
  fastfetchConfig =
    let
      shared = lib.importJSON ../configs/fastfetch/config.jsonc;
      # The DE row and the Noctalia probe that only it reads.
      desktopOnly =
        module: (module.key or "") == "DE          " || lib.hasSuffix " noctalia" (module.text or "");
    in
    pkgs.writeText "fastfetch-config.jsonc" (
      builtins.toJSON (
        shared
        // {
          logo = shared.logo // {
            source = "macOS2";
          };
          modules = builtins.filter (module: !(builtins.isAttrs module && desktopOnly module)) shared.modules;
        }
      )
    );

  # Vorssaint's modules: these on, and off the ones Tinycast, Thaw or Homebrew
  # already cover. Modules in neither list stay as each Mac has them.
  vorssaintOn = [
    "brightness"
    "finderCutPaste"
    "keepAwake"
    "middleClick"
    "mixer"
    "monitorCPU"
    "monitorDisk"
    "monitorGPU"
    "monitorMemory"
    "monitorNetwork"
    "monitorPower"
    "screenRecorder"
    "screenshot"
    "shelf"
    "smoothScroll"
    "spacesOrder"
    "switcher"
    "uninstaller"
    "urlCleaner"
  ];
  vorssaintOff = [
    "appUpdates"
    "cleaner"
    "clipboardHistory"
    "commandBar"
    "homebrew"
    "notch"
    "quickLauncher"
    "radialMenu"
    "scratchpad"
    "soundOutputSwitcher"
    "superKey"
    "textSnippets"
    "windowLayout"
    "windowMaximizer"
  ];
  features = names: value: lib.genAttrs (map (name: "featureAvailable.${name}") names) (_: value);
in
{
  imports = [ ./common.nix ];

  # Mac-only files: the macOS parts of the shared Ghostty and Git configs, and
  # the Mac apps' own settings.
  xdg.configFile = {
    "ghostty/macos".source = link "macos/ghostty";
    # Tinycast keeps this link when it saves, so its settings window writes into
    # the checkout. Caps Lock is its Hyper key for apps and Spaces; ⌃⌥ tiles
    # windows.
    "tinycast/settings.json".source = link "macos/tinycast/settings.json";
    "fastfetch/config.jsonc".source = lib.mkForce fastfetchConfig;
    # Apps started from the Dock or Finder do not get the shell's PATH, so Git
    # names 1Password's signer by its full path.
    "git/macos".text = ''
      [gpg "ssh"]
        program = ${onePasswordSigner}
    '';
  };

  programs.zed-editor = {
    # Zed comes from Homebrew; Home Manager only merges its settings.
    package = null;
    # The shared themes come from Noctalia, which only Linux has.
    userSettings = {
      theme = lib.mkForce {
        mode = "system";
        light = "GitHub Light";
        dark = "GitHub Dark";
      };
      auto_install_extensions.github-theme = true;
    };
  };

  targets.darwin = {
    # Homebrew installs every app, so Home Manager has none to copy into
    # ~/Applications and needs no App Management check.
    copyApps.enable = false;

    # App settings every Mac shares, written on each switch; restart the apps to
    # load them. Their other settings stay each Mac's own.
    defaults = {
      # Vorssaint's modules and shortcuts.
      "com.vorssaint.utils" =
        features vorssaintOn true
        // features vorssaintOff false
        // {
          # The modules' own switches, as Vorssaint's settings window sets them.
          brightnessControlEnabled = true;
          finderCutPasteEnabled = true;
          middleClickEnabled = true;
          shelfEnabled = true;
          smoothScrollEnabled = true;
          spacesOrderEnabled = true;
          switcherEnabled = true;
          urlCleanerEnabled = true;
          clipboardHistoryEnabled = false;
          notchEnabled = false;
          radialMenuEnabled = false;
          soundOutputSwitcherEnabled = false;
          superKeyEnabled = false;
          textSnippetsEnabled = false;
          windowMaximizeEnabled = false;

          launchAtLoginWanted = true;
          # Lid-closed mode needs a sudoers rule, which the Macs go without.
          clamshellPreferred = false;

          # Shortcuts as "modifiers:key code": ⇧⌘3, ⇧⌘4 and ⇧⌘5 as in macOS, which
          # darwin/ frees by turning macOS's own off; Hyper+S for the shelf, Hyper+K
          # for Keep Awake, ⌘Tab and ⌘< for the switcher.
          screenshotFullScreenShortcut = "shift+command:20";
          screenshotFullScreenShortcutEnabled = true;
          screenshotShortcut = "shift+command:21";
          screenshotShortcutEnabled = true;
          recorderShortcut = "shift+command:23";
          recorderShortcutEnabled = true;
          # Screenshots go straight to the clipboard and the Screenshots folder,
          # without the capture menu or floating preview; Hyper+E opens recent
          # captures to annotate one.
          screenshotShowCaptureMenuOnShortcut = false;
          screenshotPreviewEnabled = false;
          screenshotCopyToClipboard = true;
          screenshotSaveFolder = "${homeDirectory}/Pictures/Screenshots";
          recentCapturesShortcut = "control+option+command:14";
          recentCapturesShortcutEnabled = true;
          shelfShortcut = "control+option+command:1";
          shelfShortcutEnabled = true;
          keepAwakeShortcut = "control+option+command:40";
          switcherShortcut = "command:48";
          switcherWindowShortcut = "command:50";
          # Hyper+V is Tinycast's clipboard history.
          clipboardHistoryShortcutEnabled = false;
          quickLauncherShortcutEnabled = false;
        };

      # Itsycal with week numbers and a week of events; the calendars it shows
      # are each account's own choice.
      "com.mowglii.ItsycalApp" = {
        ShowWeeks = true;
        ShowEventDays = 7;
      };
    };
  };

  home = {
    # Homebrew has no nixd, which Zed and Neovim use for Nix files.
    packages = [ pkgs.nixd ];

    file = {
      # The shared SSH config uses the Linux socket path.
      ".1password/agent.sock".source = config.lib.file.mkOutOfStoreSymlink onePasswordAgent;
    }
    # VSCodium keeps its files under Application Support on macOS; common.nix
    # merges its settings, which take the Mac's theme.
    // lib.mapAttrs (_: name: { source = link "vscodium/${name}"; }) {
      "Library/Application Support/VSCodium/product.json" = "product.json";
      "Library/Application Support/VSCodium/User/keybindings.json" = "keybindings.json";
    };
  };
}
