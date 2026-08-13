{ pkgs, ... }:

{
  # niri ships its own wayland-session desktop file in $out/share/wayland-sessions,
  # so installing the package auto-registers the "niri" session for any
  # display manager (greetd/sddm/gdm/etc).
  environment.systemPackages = [ pkgs.niri ];
}