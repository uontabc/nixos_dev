{ pkgs, ... }:

{
  programs.kitty = {
    enable = true;
    settings = {
      font_family = "JetBrains Mono";
      font_size = 12;
      scrollback_lines = 10000;
      remember_window_size = false;
      initial_window_width = "1000";
      initial_window_height = "650";
    };
  };

  programs.yazi = {
    enable = true;
    enableBashIntegration = true;
  };
}