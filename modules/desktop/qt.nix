{
  flake.modules.nixos.qt =
    { pkgs, config, ... }:
    let
      # Qt5ct/qt6ct pick up the global fontconfig defaults (see
      # modules/config/fonts.nix) instead of their built-in fallback font.
      # QFont::toString() format: family,pointSize,pixelSize,styleHint,weight,
      # style,underline,strikeOut,fixedPitch.
      qtctConf = pkgs.writeText "qtct.conf" ''
        [Fonts]
        general="FantasqueSansM Nerd Font Mono,12,-1,5,50,0,0,0,0,0"
        fixed="FantasqueSansM Nerd Font Mono,12,-1,5,50,0,0,0,0,0"
      '';
    in
    {
      qt = {
        enable = true;
        platformTheme = "qt5ct";
      };

      # qt5ct/qt6ct configs managed by hjem (modules/hjem.nix).
      hjem.users.${config.my.name}.xdg.config.files = {
        "qt5ct/qt5ct.conf" = {
          source = qtctConf;
          clobber = true;
        };
        "qt6ct/qt6ct.conf" = {
          source = qtctConf;
          clobber = true;
        };
      };
    };
}
