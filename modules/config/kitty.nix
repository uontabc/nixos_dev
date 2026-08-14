{
  flake.modules.nixos.kitty =
    { pkgs, config, ... }:
    let
      kittyConfig = pkgs.writeText "kitty.conf" ''
        font_family      JetBrains Mono
        font_size        12.0
        scrollback_lines 10000
        remember_window_size no
        initial_window_width  1000
        initial_window_height 650
      '';
      home = "/home/${config.my.name}";
    in
    {
      my.packages = [ pkgs.kitty ];

      systemd.tmpfiles.rules = [
        "d ${home}/.config/kitty 0755 ${config.my.name} users -"
        "L+ ${home}/.config/kitty/kitty.conf - - - - ${kittyConfig}"
      ];
    };
}