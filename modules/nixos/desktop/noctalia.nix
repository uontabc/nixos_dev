{ pkgs, ... }:

{
  security.polkit.enable = true;

  services.gnome.gnome-keyring.enable = true;

  services.upower.enable = true;

  services.power-profiles-daemon.enable = true;

  environment.systemPackages = [ pkgs.ddcutil ];
}