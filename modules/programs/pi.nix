{
  flake.modules.nixos.pi =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    let
      home = "/home/${config.my.name}";
      agentDir = "${home}/.pi/agent";

      piSettings = pkgs.writeText "pi-settings.json" (
        builtins.toJSON (
          {
            # Startup model defaults. Change interactively with /model + Ctrl+S.
            defaultProvider = "deepseek";
            defaultModel = "deepseek-chat";
            defaultThinkingLevel = "medium";

            theme = "dark";

            # Version is managed by nix — no update pings.
            enableInstallTelemetry = false;
          }
          // lib.optionalAttrs (config.my.piHttpProxy != null) {
            # Fixes "Error: Connection error." (openai SDK APIConnectionError)
            # when api.deepseek.com is unreachable directly — applied as
            # HTTP_PROXY/HTTPS_PROXY for all pi requests.
            httpProxy = config.my.piHttpProxy;
          }
        )
      );
    in
    {
      my.packages = [ pkgs.pi-coding-agent ];

      # pi.dev (version/update pings) is unreachable in CN; skip it so pi
      # doesn't hang/error on startup. Set in the shell environment.
      environment.sessionVariables = {
        PI_SKIP_VERSION_CHECK = "1";
      };

      systemd.tmpfiles.rules = [
        "d ${home}/.pi 0700 ${config.my.name} users -"
        "d ${agentDir} 0700 ${config.my.name} users -"
        "L+ ${agentDir}/settings.json - - - - ${piSettings}"
      ];

      # API keys live in ~/.pi/agent/auth.json (0600), e.g.
      #   {"deepseek": {"type": "api_key", "key": "sk-..."}}
      # Create it with `pi`'s /login or write it yourself (DEEPSEEK_API_KEY
      # env var also works). `~/.pi` is persisted by impermanence, so it
      # survives reboots.
      #
      # If you get "Error: Connection error." when talking to the model, set
      # `my.piHttpProxy` in modules/system/users.nix to your local proxy
      # (e.g. "http://127.0.0.1:7890") — deepseek's API is OpenAI-compatible
      # and pi routes through HTTP_PROXY/HTTPS_PROXY.
    };
}
