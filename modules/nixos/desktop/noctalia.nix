{ pkgs, ... }:

{
  # Noctalia v5 desktop shell (system level).
  # The flake injects `noctalia.nixosModules.default`, which provides
  # `programs.noctalia.{enable,package,systemd,recommendedServices}`.
  programs.noctalia = {
    enable = true;
    # Let systemd manage noctalia (auto-start on graphical-session, auto-restart on crash).
    systemd.enable = true;
  };

  # System services noctalia expects to talk to.
  security.polkit.enable = true;
  services.gnome.gnome-keyring.enable = true;
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;

  environment.systemPackages = [ pkgs.ddcutil ];
}