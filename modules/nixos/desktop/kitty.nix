{ pkgs, ... }:

let
  kittyConfig = pkgs.writeText "kitty.conf" ''
    font_family      JetBrains Mono
    font_size        12.0
    scrollback_lines 10000
    remember_window_size no
    initial_window_width  1000
    initial_window_height 650
  '';
in
{
  # kitty terminal is installed via users.users.onyx.packages in core/users.nix.
  # Here we only symlink the config into the user's home.
  systemd.tmpfiles.rules = [
    "d /home/onyx/.config/kitty 0755 onyx users -"
    "L+ /home/onyx/.config/kitty/kitty.conf - - - - ${kittyConfig}"
  ];
}