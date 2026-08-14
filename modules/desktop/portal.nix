{
  flake.modules.nixos.portal =
    { pkgs, ... }: {
      xdg.portal = {
        enable = true;
        # niri 25.08+ handles screencasting internally; only the GTK portal
        # is needed for file pickers etc. `xdg.portal.wlr` is deprecated
        # and removed on nixos-26.05.
        extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
        config.common.default = [ "gtk" ];
      };
    };
}