{
  flake.modules.nixos.pi =
    { pkgs, config, ... }:
    let
      home = "/home/${config.my.name}";
      agentDir = "${home}/.pi/agent";

      piSettings = pkgs.writeText "pi-settings.json" (
        builtins.toJSON {
          # Startup model defaults. Change interactively with /model + Ctrl+S.
          defaultProvider = "deepseek";
          defaultModel = "deepseek-chat";
          defaultThinkingLevel = "medium";

          theme = "dark";

          # Version is managed by nix — no update pings.
          enableInstallTelemetry = false;
        }
      );
    in
    {
      my.packages = [ pkgs.pi-coding-agent ];

      systemd.tmpfiles.rules = [
        "d ${home}/.pi 0700 ${config.my.name} users -"
        "d ${agentDir} 0700 ${config.my.name} users -"
        "L+ ${agentDir}/settings.json - - - - ${piSettings}"
      ];

      # API keys live in ~/.pi/agent/auth.json (0600), e.g.
      # {"deepseek": {"type": "api_key", "key": "sk-..."}}
      # Create it with `pi`'s /login or write it yourself. `~/.pi` is
      # persisted by impermanence, so it survives reboots.
    };
}
