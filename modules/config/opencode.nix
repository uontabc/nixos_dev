{
  flake.modules.nixos.opencode =
    { pkgs, config, ... }:
    let
      home = "/home/${config.my.name}";
      authDir = "${home}/.local/share/opencode";

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
        "d ${authDir} 0700 ${config.my.name} users -"
      ];

      # API keys live in ~/.local/share/opencode/auth.json; the content of the
      # vaultix secret IS that file (e.g. {"deepseek": {"api_key": "..."}}).
      vaultix.secrets.opencode-auth = {
        owner = config.my.name;
        group = "users";
        mode = "0600";
      };

      systemd.services.opencode-auth = {
        description = "Deploy opencode auth.json from vaultix secret";
        after = [ "vaultix-activate.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig.Type = "oneshot";
        path = [ pkgs.coreutils ];
        script = ''
          install -d -o ${config.my.name} -g users -m 0700 ${authDir}
          install -o ${config.my.name} -g users -m 0600 /run/vaultix/opencode-auth ${authDir}/auth.json
        '';
      };
    };
}