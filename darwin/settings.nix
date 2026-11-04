# macOS settings for my account, as mac-setup wrote them on macOS 27.0.1, and
# matching Linux where it has an equivalent. Each switch writes them; most take
# effect then, the rest after a logout.
{ lib, ... }:

let
  # F19's key equivalent character, U+F716.
  f19 = builtins.fromJSON ''""'';
in
{
  system.defaults = {
    finder = {
      AppleShowAllFiles = true;
      _FXSortFoldersFirst = true;
      ShowPathbar = true;
      # Search the current folder, not the whole Mac.
      FXDefaultSearchScope = "SCcf";
    };

    NSGlobalDomain = {
      AppleShowAllExtensions = true;
      AppleInterfaceStyle = "Dark";
      # Fast key repeat; held keys repeat instead of offering accents.
      KeyRepeat = 2;
      InitialKeyRepeat = 15;
      ApplePressAndHoldEnabled = false;
      # No automatic text changes.
      NSAutomaticSpellingCorrectionEnabled = false;
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticInlinePredictionEnabled = false;
      # Tap to click everywhere, and natural scrolling.
      "com.apple.mouse.tapBehavior" = 1;
      "com.apple.swipescrolldirection" = true;
    };

    # Built-in and Bluetooth trackpads: tap to click, and three fingers swipe
    # between Spaces.
    trackpad = {
      Clicking = true;
      TrackpadThreeFingerHorizSwipeGesture = 2;
    };

    # No macOS tiling; Tinycast tiles.
    WindowManager = {
      EnableTilingByEdgeDrag = false;
      EnableTopTilingByEdgeDrag = false;
      EnableTilingOptionAccelerator = false;
      # Clicking the wallpaper never pushes the windows aside.
      EnableStandardClickToShowDesktop = false;
    };

    # Spaces separate on each display, and in a fixed order below.
    spaces.spans-displays = false;

    dock = {
      mru-spaces = false;
      # Hidden, with only open apps and no recents.
      autohide = true;
      static-only = true;
      show-recents = false;
      minimize-to-application = true;
    };

    CustomUserPreferences = {
      # No .DS_Store files on network shares and USB drives.
      "com.apple.desktopservices" = {
        DSDontWriteNetworkStores = true;
        DSDontWriteUSBStores = true;
      };

      # ⌘M never minimises. Turning off Minimize in shortcuts.nix still left ⌘M
      # minimising Finder windows on macOS 27.0.1, so the Minimize item in every
      # app gets ⌃⌥⇧⌘F19 instead, as App Shortcuts in System Settings does. No
      # Mac keyboard has F19, so Caps Lock's Hyper chord cannot reach it either.
      # Danish menu title first, English for apps without Danish. Each switch
      # writes the whole list, so add App Shortcuts for all apps here.
      NSGlobalDomain.NSUserKeyEquivalents = lib.genAttrs [ "Minimer" "Minimize" ] (_: "@~^$" + f19);
    };
  };
}
