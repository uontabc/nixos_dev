{
  flake.modules.nixos.opencode =
    { pkgs, config, ... }:
    let
      home = "/home/${config.my.name}";

      opencodeConfig = pkgs.writeText "opencode.json" (
        builtins.toJSON {
          "$schema" = "https://opencode.ai/config.json";
          username = config.my.name;
          # Version is managed by nix — no auto-update.
          autoupdate = false;
          # Don't share sessions unless explicitly asked.
          share = "manual";
        }
      );
    in
    {
      my.packages = [ pkgs.opencode ];

      systemd.tmpfiles.rules = [
        "d ${home}/.config/opencode 0755 ${config.my.name} users -"
        "L+ ${home}/.config/opencode/opencode.json - - - - ${opencodeConfig}"
      ];
    };
}