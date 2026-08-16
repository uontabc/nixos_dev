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
      home = "/home/${config.my.name}";
    in
    {
      qt = {
        enable = true;
        platformTheme = "qt5ct";
      };

      systemd.tmpfiles.rules = [
        "d ${home}/.config/qt5ct 0755 ${config.my.name} users -"
        "L+ ${home}/.config/qt5ct/qt5ct.conf - - - - ${qtctConf}"
        "d ${home}/.config/qt6ct 0755 ${config.my.name} users -"
        "L+ ${home}/.config/qt6ct/qt6ct.conf - - - - ${qtctConf}"
      ];
    };
}
