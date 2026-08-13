{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    git
    htop
    man-pages

    qt6ct
    networkmanagerapplet
    brightnessctl
    polkit_gnome
  ];
}