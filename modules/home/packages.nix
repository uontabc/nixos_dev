{ pkgs, ... }:

{
  home.packages = with pkgs; [
    kitty
    yazi
    superfile
    satty
    wl-clipboard
    qt6ct
  ];
}