{
  flake.modules.nixos.fastfetch =
    { pkgs, config, ... }:
    let
      home = "/home/${config.my.name}";

      esc = builtins.fromJSON ''"\u001b"'';
      blue = "${esc}[38;2;82;119;195m";
      reset = "${esc}[0m";

      logo = pkgs.writeText "nixos-ascii.txt" ''
        ${blue}          ▗▄▄▄       ▗▄▄▄▄    ▄▄▄▖
        ${blue}          ▜   ▙       ▜   ▙  ▟   ▛
        ${blue}           ▜   ▙       ▜   ▙▟   ▛
        ${blue}            ▜   ▙       ▜      ▛
        ${blue}     ▟██████     ██████▙ ▜    ▛     ▟▙
        ${blue}    ▟██████     ████████▙ ▜   ▙    ▟  ▙
        ${blue}           ▄   ▖           ▜   ▙  ▟   ▛
        ${blue}          ▟   ▛             ▜  ▛ ▟   ▛
        ${blue}         ▟   ▛               ▜▛ ▟   ▛
        ${blue}▟████████   ▛                  ▟     █████▙
        ${blue}▜█████     ▛                  ▟   ████████▛
        ${blue}      ▟   ▛ ▟▙               ▟   ▛
        ${blue}     ▟   ▛ ▟  ▙             ▟   ▛
        ${blue}    ▟   ▛  ▜   ▙           ▝   ▀
        ${blue}    ▜  ▛    ▜   ▙ ▜████████     █████▛
        ${blue}     ▜▛     ▟    ▙ ▜████████     ███▛
        ${blue}           ▟      ▙         ▜   ▙
        ${blue}          ▟   ▛▜   ▙         ▜   ▙
        ${blue}         ▟   ▛  ▜   ▙         ▜   ▙
        ${blue}         ▝▀▀▀    ▀▀▀▀▘         ▀▀▀▘${reset}
      '';

      fastfetchCentered = pkgs.writeShellScriptBin "fastfetch-centered" ''
        ${pkgs.fastfetch}/bin/fastfetch "$@" | ${pkgs.perl}/bin/perl -e '
          my $w = $ENV{COLUMNS} // 80;
          while (<>) {
            my $col = 1;
            while (/\G(.*?)(\e\[([0-9;?]*)([A-Za-z])|\e\][^\a]*\a|\z)/g) {
              $col += length($1);
              my ($p, $c) = ($3, $4);
              last unless defined $c;
              if ($c eq "G") { $col = ($p =~ /^(\d+)/) ? $1 : 1; }
              elsif ($c eq "C") { $col += ($p =~ /^(\d+)/) ? $1 : 1; }
            }
            my $pad = int(($w - ($col - 1)) / 2);
            $pad = 0 if $pad < 0;
            print " " x $pad, $_;
          }'
      '';

      fastfetchConfig = pkgs.writeText "fastfetch.jsonc" (
        builtins.toJSON {
          "$schema" = "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json";

          logo = {
            source = "${logo}";
            type = "file";
            padding = {
              top = 0;
              left = 2;
            };
          };

          display = {
            separator = "  ";
            key = {
              width = 16;
            };
          };

          modules = [
            "break"
            "break"
            "break"
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
            "break"
          ];
        }
      );
    in
    {
      my.packages = [
        pkgs.fastfetch
        fastfetchCentered
      ];

      systemd.tmpfiles.rules = [
        "d ${home}/.config/fastfetch 0755 ${config.my.name} users -"
        "L+ ${home}/.config/fastfetch/config.jsonc - - - - ${fastfetchConfig}"
      ];
    };
}
