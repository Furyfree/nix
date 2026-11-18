# The session environment both Linux desktops share: components/desktop.nix
# sets it at login on NixOS, home/ubuntu.nix through systemd on Ubuntu.
# home/linux.nix reads the cursor from it. An attribute set, not a module.
{
  # Prefer native Wayland, with X11 as a fallback. GTK does so by itself;
  # components/hyprland.nix forces it there only.
  QT_QPA_PLATFORM = "wayland;xcb";
  ELECTRON_OZONE_PLATFORM_HINT = "auto";
  GTK_IM_MODULE = "simple";
  # qt6ct also accepts qt5ct, so both Qt generations load their plugin.
  QT_QPA_PLATFORMTHEME = "qt5ct";
  XCURSOR_THEME = "Bibata-Modern-Ice";
  XCURSOR_SIZE = "24";
  # Hyprland's cursor library; other desktops ignore these.
  HYPRCURSOR_THEME = "Bibata-Modern-Ice";
  HYPRCURSOR_SIZE = "24";
}
