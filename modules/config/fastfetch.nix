{
  flake.modules.nixos.fastfetch =
    { pkgs, config, ... }:
    let
      home = "/home/${config.my.name}";

      logo = pkgs.writeText "nixos-ascii.txt" ''
             _______
            /       \
           |  NixOS  |
           |         |
            \_______/
              |   |
             /|   |\
            / |___| \
      '';

      fastfetchConfig = pkgs.writeText "fastfetch.jsonc" (
        builtins.toJSON {
          "$schema" = "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json";

          logo = {
            source = "${logo}";
            type = "file";
            padding = {
              top = 2;
              left = 2;
            };
          };

          display = {
            separator = "  →  ";
            key = {
              width = 16;
            };
          };

          modules = [
            {
              type = "title";
              keyWidth = 16;
            }
            "separator"
            "os"
            "kernel"
            "uptime"
            "packages"
            "shell"
            "display"
            "de"
            "wm"
            "terminal"
            "cpu"
            "gpu"
            "memory"
            "disk"
            "battery"
            "locale"
            "break"
          ];
        }
      );
    in
    {
      my.packages = [ pkgs.fastfetch ];

      systemd.tmpfiles.rules = [
        "d ${home}/.config/fastfetch 0755 ${config.my.name} users -"
        "L+ ${home}/.config/fastfetch/config.jsonc - - - - ${fastfetchConfig}"
      ];
    };
}
