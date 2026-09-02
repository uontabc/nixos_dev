{
  # File manager: PCManFM (lightweight GTK3 FM), replacing Thunar (which was
  # ported from the old codeberg nix-config repo). PCManFM ships no NixOS
  # module, so: install the package, keep gvfs (trash / removable drives) and
  # tumbler (freedesktop thumbnailer) enabled, and register it as the default
  # handler for folders.
  flake.modules.nixos.pcmanfm =
    { pkgs, ... }:
    {
      services = {
        gvfs.enable = true;
        tumbler.enable = true;
      };

      environment.systemPackages = [ pkgs.pcmanfm ];

      # Open folders (portal "open folder", other apps' file pickers) in
      # PCManFM. Requires the system mimeapps list (xdg.mime.enable).
      xdg.mime = {
        enable = true;
        defaultApplications = {
          "inode/directory" = "pcmanfm.desktop";
        };
      };
    };
}
