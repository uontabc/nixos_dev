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

      # API keys live in ~/.local/share/opencode/auth.json
      # (e.g. {"deepseek": {"api_key": "..."}}). Manage it manually:
      #   opencode auth login   # or write the file yourself
      # (`.local/share` is persisted by impermanence, so it survives reboots.)
    };
}