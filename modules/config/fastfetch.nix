{
  flake.modules.nixos.fastfetch =
    { pkgs, config, ... }:
    let
      home = "/home/${config.my.name}";
      esc = builtins.fromJSON ''"\u001b"'';
      reset = "${esc}[0m";

      blue1 = "${esc}[38;2;126;156;216m";
      blue2 = "${esc}[38;2;82;119;195m";
      blue3 = "${esc}[38;2;58;90;153m";

      logo = pkgs.writeText "nixos-ascii.txt" ''
        ${blue1}      /\
        ${blue1}     /  \
        ${blue1}    / /\ \
        ${blue2}   / /__\ \
        ${blue2}  |  NixOS  |
        ${blue2}  |         |
        ${blue2}   \______/
        ${blue3}     |  |
        ${blue3}    /|  |\
        ${blue3}   / |__| \${reset}
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
            {
              type = "battery";
              key = "Battery";
            }
            "colors"
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
