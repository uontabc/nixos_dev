{ ... }:

{
  # System-level Qt theming (NixOS has `qt.platformTheme`, not `qt.platformTheme.name`
  # like home-manager). This sets QT_QPA_PLATFORMTHEME in the environment.
  qt = {
    enable = true;
    platformTheme = "qt6ct";
  };
}