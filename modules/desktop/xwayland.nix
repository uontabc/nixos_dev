{
  flake.modules.nixos.xwayland =
    { pkgs, ... }:
    {
      # niri 25.08+ integrates xwayland-satellite out of the box: it creates
      # X11 sockets, exports $DISPLAY, spawns xwayland-satellite on demand,
      # and auto-restarts on crash. We just need the binary in PATH.
      # Do NOT run xwayland-satellite as a separate systemd service — it
      # conflicts with niri's built-in integration.
      # Ref: https://niri-wm.github.io/niri/Xwayland.html
      environment.systemPackages = [ pkgs.xwayland-satellite ];
    };
}