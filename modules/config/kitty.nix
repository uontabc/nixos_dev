{
  flake.modules.nixos.kitty =
    { pkgs, config, ... }:
    let
      kittyConfig = pkgs.writeText "kitty.conf" ''
        font_family      FantasqueSansM Nerd Font Mono
        font_size        13.0
        scrollback_lines 10000
        background       #1a1b26
        remember_window_size no
        # 0 = never ask when the OS window is closed (Mod+Q closes instantly).
        confirm_os_window_close 0
        initial_window_width  1000
        initial_window_height 650

        # Always-visible tab bar (even with one tab) in Tokyo Night colors.
        tab_bar_edge         top
        tab_bar_style        powerline
        tab_bar_min_tabs     1
        tab_bar_margin_width 6
        active_tab_foreground   #1a1b26
        active_tab_background   #7aa2f7
        active_tab_font_style   bold
        inactive_tab_foreground #c0caf5
        inactive_tab_background #16161e
        inactive_tab_font_style normal

        # New terminal shortcuts: no more reaching for Mod+Return.
        map ctrl+shift+t  new_tab_with_cwd
        map ctrl+shift+n  new_window_with_cwd
        map ctrl+shift+right next_tab
        map ctrl+shift+left  previous_tab
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
