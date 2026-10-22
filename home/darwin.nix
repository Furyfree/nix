# Standalone Home Manager settings for macOS. Swift mac-setup installs the apps
# and command-line tools (INSTALLATION.md lists them) and owns system settings;
# this only links the shared configs and maps them to macOS paths. Builds on
# common.nix.
{
  config,
  lib,
  ...
}:

let
  inherit (config.home) homeDirectory;
  link = path: config.lib.file.mkOutOfStoreSymlink "${homeDirectory}/Projects/nix/configs/${path}";
  # 1Password's app bundle holds its SSH agent socket and Git signer.
  onePasswordAgent = "${homeDirectory}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
  onePasswordSigner = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
in
{
  imports = [ ./common.nix ];

  # Zed comes from mac-setup; Home Manager only merges its settings.
  programs.zed-editor.package = null;

  home = {
    # Usernames come from the ignored hosts/macos/local/user.nix.
    homeDirectory = lib.mkDefault "/Users/${config.home.username}";

    file = {
      # The shared SSH config uses the Linux socket path.
      ".1password/agent.sock".source = config.lib.file.mkOutOfStoreSymlink onePasswordAgent;
      # The shared Git config signs with op-ssh-sign from PATH.
      ".local/bin/op-ssh-sign".source = config.lib.file.mkOutOfStoreSymlink onePasswordSigner;
    }
    # VSCodium keeps its settings under Application Support on macOS.
    // lib.mapAttrs (_: name: { source = link "vscodium/${name}"; }) {
      "Library/Application Support/VSCodium/product.json" = "product.json";
      "Library/Application Support/VSCodium/User/settings.json" = "settings.json";
      "Library/Application Support/VSCodium/User/keybindings.json" = "keybindings.json";
    };
  };
}
